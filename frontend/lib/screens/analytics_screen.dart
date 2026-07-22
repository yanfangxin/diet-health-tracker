import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final SupabaseService _supabaseService;
  List<DailyLog> _weeklyLogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _fetchWeeklyData();
  }

  Future<void> _fetchWeeklyData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 6));
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = now.toIso8601String().split('T')[0];

    try {
      final logs = await _supabaseService.fetchWeeklyLogs(startDateStr, endDateStr);
      if (mounted) {
        setState(() {
          _weeklyLogs = logs;
        });
      }
    } catch (e) {
      debugPrint("讀取週分析數據失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 計算近 7 天平均數據
    double avgWater = 0;
    double avgSleep = 0;
    double latestWeight = 0;

    if (_weeklyLogs.isNotEmpty) {
      final totalWater = _weeklyLogs.fold<int>(0, (sum, log) => sum + log.waterIntakeMl);
      final totalSleep = _weeklyLogs.fold<int>(0, (sum, log) => sum + log.sleepMinutes);
      avgWater = totalWater / _weeklyLogs.length;
      avgSleep = (totalSleep / _weeklyLogs.length) / 60.0;

      final validWeights = _weeklyLogs.where((l) => l.weightKg > 0).toList();
      if (validWeights.isNotEmpty) {
        latestWeight = validWeights.last.weightKg;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('健康數據與 7 日趨勢', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWeeklyData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchWeeklyData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 週平均摘要卡片
                    const Text('📊 7 日平均紀錄摘要', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            '平均飲水',
                            '${avgWater.round()}',
                            'ml/日',
                            Icons.water_drop,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryItem(
                            '平均睡眠',
                            avgSleep.toStringAsFixed(1),
                            '小時/日',
                            Icons.bedtime,
                            Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryItem(
                            '最新體重',
                            latestWeight > 0 ? latestWeight.toString() : '--',
                            'kg',
                            Icons.monitor_weight,
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text('💧 近 7 天飲水量變化趨勢', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // 飲水量 7 日條形趨勢圖
                    _buildWeeklyWaterChart(),

                    const SizedBox(height: 24),
                    const Text('📅 歷史紀錄明細清單', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (_weeklyLogs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: Text('目前尚無過去 7 天的歷史紀錄')),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _weeklyLogs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = _weeklyLogs[index];
                          final sleepH = (log.sleepMinutes / 60.0).toStringAsFixed(1);
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  log.date.length >= 10 ? log.date.substring(5) : log.date,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                              ),
                              title: Text(
                                log.date,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '💧 喝水: ${log.waterIntakeMl} ml  |  😴 睡眠: $sleepH 小時',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                log.weightKg > 0 ? '${log.weightKg} kg' : '-- kg',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildWeeklyWaterChart() {
    const double maxWaterTarget = 2500.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final dayDate = DateTime.now().subtract(Duration(days: 6 - i));
                final dayStr = dayDate.toIso8601String().split('T')[0];

                final match = _weeklyLogs.firstWhere(
                  (l) => l.date == dayStr,
                  orElse: () => DailyLog(date: dayStr),
                );

                final ratio = (match.waterIntakeMl / maxWaterTarget).clamp(0.0, 1.0);
                final height = ratio * 100 + 10; // 最低給 10px 高度

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${match.waterIntakeMl}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: height,
                      decoration: BoxDecoration(
                        color: ratio >= 0.8 ? Colors.blue.shade600 : Colors.blue.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${dayDate.month}/${dayDate.day}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
