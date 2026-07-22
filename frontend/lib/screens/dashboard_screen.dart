import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/user_goals.dart';
import '../services/supabase_service.dart';
import '../widgets/ai_food_recognition_dialog.dart';
import '../widgets/stat_card.dart';
import '../widgets/update_health_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final UserGoals userGoals;
  final VoidCallback? onOpenGoalSettings;

  const DashboardScreen({
    super.key,
    this.userGoals = const UserGoals(),
    this.onOpenGoalSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final SupabaseService _supabaseService;

  DailyLog _dailyLog = DailyLog(date: DateTime.now().toIso8601String().split('T')[0]);
  int _totalCalories = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _fetchTodayData();
  }

  String get _todayStr => DateTime.now().toIso8601String().split('T')[0];

  Future<void> _fetchTodayData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _supabaseService.fetchTodayData(_todayStr);

      int caloriesSum = 0;
      for (var food in result.foodLogs) {
        caloriesSum += food.calories;
      }

      if (mounted) {
        setState(() {
          _dailyLog = result.dailyLog ?? DailyLog(date: _todayStr);
          _totalCalories = caloriesSum;
        });
      }
    } catch (e) {
      debugPrint("讀取資料失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater(int amountMl) async {
    final updatedWater = _dailyLog.waterIntakeMl + amountMl;
    final messenger = ScaffoldMessenger.of(context);

    // 樂觀更新 (Optimistic UI Update)
    final previousLog = _dailyLog;
    setState(() {
      _dailyLog = _dailyLog.copyWith(waterIntakeMl: updatedWater);
    });

    try {
      await _supabaseService.upsertDailyLog(_dailyLog);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('💧 已成功增加 ${amountMl}ml 飲水量！'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // 失敗時復原
      if (mounted) setState(() => _dailyLog = previousLog);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('加水失敗：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAiFoodRecognitionDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AiFoodRecognitionDialog(
        dateStr: _todayStr,
        onSave: (foodLog) async {
          await _supabaseService.addFoodLog(foodLog);
          if (mounted) {
            _fetchTodayData();
            messenger.showSnackBar(
              SnackBar(
                content: Text('✨ 已成功新增 AI 辨識餐點：${foodLog.foodName} (${foodLog.calories} kcal)'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
      ),
    );
  }

  void _showUpdateHealthDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return UpdateHealthDialog(
          currentWeight: _dailyLog.weightKg,
          currentSleepMinutes: _dailyLog.sleepMinutes,
          onSave: (weight, sleepMinutes) async {
            final updatedLog = _dailyLog.copyWith(
              weightKg: weight,
              sleepMinutes: sleepMinutes,
            );
            await _supabaseService.upsertDailyLog(updatedLog);
            if (mounted) {
              setState(() => _dailyLog = updatedLog);
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('✅ 今日健康數據更新成功！'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = widget.userGoals;
    final sleepHours = _dailyLog.sleepMinutes / 60.0;
    final sleepHoursStr = sleepHours.toStringAsFixed(1);
    final weightStr = _dailyLog.weightKg > 0 ? _dailyLog.weightKg.toString() : '--';

    // 計算目標進度比例
    final waterProgress = _dailyLog.waterIntakeMl / goals.targetWaterMl;
    final caloriesProgress = _totalCalories / goals.targetCalories;
    final sleepProgress = sleepHours / goals.targetSleepHours;

    return Scaffold(
      backgroundColor: const Color(0xFFA5F6FA).withValues(alpha: 0.12),
      appBar: AppBar(
        title: const Text('今日健康儀表板', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: widget.onOpenGoalSettings,
            tooltip: '目標設定',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTodayData,
            tooltip: '重新整理',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTodayData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 今日日期與歡迎橫幅
                    _buildBannerCard(),

                    const SizedBox(height: 20),

                    // 4 大指標卡片網格
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        StatCard(
                          title: '熱量攝取',
                          value: '$_totalCalories',
                          unit: 'kcal',
                          icon: Icons.local_fire_department,
                          color: Colors.deepOrange,
                          progress: caloriesProgress,
                          subtitle: '目標 ${goals.targetCalories} kcal',
                        ),
                        StatCard(
                          title: '喝水量',
                          value: '${_dailyLog.waterIntakeMl}',
                          unit: 'ml',
                          icon: Icons.water_drop,
                          color: Colors.blue.shade600,
                          progress: waterProgress,
                          subtitle: '目標 ${goals.targetWaterMl} ml',
                        ),
                        StatCard(
                          title: '睡眠時間',
                          value: sleepHoursStr,
                          unit: '小時',
                          icon: Icons.bedtime,
                          color: Colors.indigo,
                          progress: sleepProgress,
                          subtitle: '目標 ${goals.targetSleepHours.toInt()} 小時',
                        ),
                        StatCard(
                          title: '今日體重',
                          value: weightStr,
                          unit: 'kg',
                          icon: Icons.monitor_weight,
                          color: Colors.teal.shade700,
                          subtitle: _dailyLog.weightKg > 0 ? '已記錄' : '未記錄',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Text(
                      '🚀 快速紀錄與功能',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 快速功能選單列表
                    _buildActionCard(
                      icon: Icons.local_drink,
                      iconBgColor: Colors.blue.shade100,
                      iconColor: Colors.blue.shade700,
                      title: '記錄喝水 (+250ml)',
                      subtitle: '快速補水，邁向每日 ${goals.targetWaterMl}ml 目標',
                      trailing: Icon(Icons.add_circle, color: Colors.blue.shade600, size: 28),
                      onTap: () => _addWater(250),
                    ),
                    const SizedBox(height: 10),
                    _buildActionCard(
                      icon: Icons.camera_alt,
                      iconBgColor: Colors.orange.shade100,
                      iconColor: Colors.orange.shade800,
                      title: 'AI 拍照辨識飲食',
                      subtitle: '上傳餐點照片，自動預估熱量與食物成分',
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: _showAiFoodRecognitionDialog,
                    ),
                    const SizedBox(height: 10),
                    _buildActionCard(
                      icon: Icons.edit_note,
                      iconBgColor: Colors.teal.shade100,
                      iconColor: Colors.teal.shade800,
                      title: '更新體重 / 睡眠',
                      subtitle: '輸入今日體重與昨晚睡眠時間',
                      trailing: Icon(Icons.edit, color: Colors.teal.shade700),
                      onTap: _showUpdateHealthDialog,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📅 今天：$_todayStr',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '保持健康飲食與規律作息 ✨',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: iconBgColor,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
