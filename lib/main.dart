import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 載入 .env 檔案
  await dotenv.load(fileName: ".env");

  // 從 .env 讀取金鑰
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const DietTrackerApp());
}

class DietTrackerApp extends StatelessWidget {
  const DietTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '個人飲食健康管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _waterMl = 0;
  int _sleepMinutes = 0;
  double _weight = 0.0;
  int _totalCalories = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTodayData();
  }

  // 取得今天的日期字串 (例如: 2026-07-22)
  String get _todayStr => DateTime.now().toIso8601String().split('T')[0];

  // 1. 從 Supabase 讀取今日數據
  Future<void> _fetchTodayData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 讀取今日飲水/睡眠/體重
      final dailyLog = await supabase
          .from('diet_daily_logs')
          .select()
          .eq('date', _todayStr)
          .maybeSingle();

      // 讀取今日飲食熱量
      final foodLogs = await supabase
          .from('diet_food_logs')
          .select('calories')
          .eq('logged_date', _todayStr);

      int caloriesSum = 0;
      for (var food in foodLogs) {
        caloriesSum += (food['calories'] as int);
      }

      if (mounted) {
        setState(() {
          if (dailyLog != null) {
            _waterMl = dailyLog['water_intake_ml'] ?? 0;
            _sleepMinutes = dailyLog['sleep_minutes'] ?? 0;
            _weight = (dailyLog['weight_kg'] as num?)?.toDouble() ?? 0.0;
          } else {
            _waterMl = 0;
            _sleepMinutes = 0;
            _weight = 0.0;
          }
          _totalCalories = caloriesSum;
        });
      }
    } catch (e) {
      debugPrint("讀取資料失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 實作「一鍵 +250ml 喝水」
  Future<void> _addWater(int amountMl) async {
    final supabase = Supabase.instance.client;
    final newWaterTotal = _waterMl + amountMl;

    try {
      // 使用 upsert：若今天資料已存在則更新，不存在則自動建立
      await supabase.from('diet_daily_logs').upsert({
        'date': _todayStr,
        'water_intake_ml': newWaterTotal,
        'sleep_minutes': _sleepMinutes,
        'weight_kg': _weight > 0 ? _weight : null,
      }, onConflict: 'date');

      _fetchTodayData(); // 重新整理畫面

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('💧 已成功增加 ${amountMl}ml 飲水量！')),
        );
      }
    } catch (e) {
      debugPrint("加水失敗: $e");
    }
  }

  // 3. 實作「更新體重與睡眠」彈出對話框
  void _showUpdateHealthDialog() {
    final weightController = TextEditingController(text: _weight > 0 ? _weight.toString() : '');
    final sleepHoursController = TextEditingController(
      text: _sleepMinutes > 0 ? (_sleepMinutes / 60).toStringAsFixed(1) : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('記錄今日體重與睡眠'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '今日體重 (kg)',
                  hintText: '例如: 65.5',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sleepHoursController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '昨晚睡眠時數 (小時)',
                  hintText: '例如: 7.5',
                  suffixText: '小時',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? inputWeight = double.tryParse(weightController.text);
                final double? inputSleepHours = double.tryParse(sleepHoursController.text);

                final int sleepMins = inputSleepHours != null ? (inputSleepHours * 60).round() : _sleepMinutes;
                final double weightVal = inputWeight ?? _weight;

                final supabase = Supabase.instance.client;
                await supabase.from('diet_daily_logs').upsert({
                  'date': _todayStr,
                  'water_intake_ml': _waterMl,
                  'sleep_minutes': sleepMins,
                  'weight_kg': weightVal > 0 ? weightVal : null,
                }, onConflict: 'date');

                if (context.mounted) Navigator.pop(context);
                _fetchTodayData();
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日健康儀表板', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTodayData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📅 今天：$_todayStr',
                    style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // 數據摘要卡片網格
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard('🔥 熱量攝取', '$_totalCalories', 'kcal', Colors.orange),
                      _buildStatCard('💧 喝水量', '$_waterMl', 'ml', Colors.blue),
                      _buildStatCard('😴 睡眠時間', '${(_sleepMinutes / 60).toStringAsFixed(1)}', '小時', Colors.indigo),
                      _buildStatCard('⚖️ 體重', _weight > 0 ? '$_weight' : '--', 'kg', Colors.green),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('🚀 快速功能紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // 功能按鈕區
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.local_drink, color: Colors.white)),
                    title: const Text('記錄喝水 (+250ml)'),
                    subtitle: const Text('點擊快速增加 250ml 飲水量'),
                    trailing: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                    onTap: () => _addWater(250), // 綁定加水邏輯
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.camera_alt, color: Colors.white)),
                    title: const Text('AI 拍照辨識飲食'),
                    subtitle: const Text('上傳餐點照片自動估算熱量'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // 下一步要寫的 Gemini AI 辨識
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.monitor_weight, color: Colors.white)),
                    title: const Text('更新體重 / 睡眠'),
                    subtitle: const Text('輸入今日體重與昨晚睡眠時間'),
                    trailing: const Icon(Icons.edit, color: Colors.green),
                    onTap: _showUpdateHealthDialog, // 綁定彈出視窗
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}