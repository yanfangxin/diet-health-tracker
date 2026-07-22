import 'package:flutter/material.dart';
import '../models/food_log.dart';
import '../services/supabase_service.dart';
import '../widgets/add_food_dialog.dart';

class FoodLogsScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const FoodLogsScreen({super.key, this.onDataChanged});

  @override
  State<FoodLogsScreen> createState() => _FoodLogsScreenState();
}

class _FoodLogsScreenState extends State<FoodLogsScreen> {
  late final SupabaseService _supabaseService;
  List<FoodLog> _foodLogs = [];
  bool _isLoading = false;

  String get _todayStr => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _fetchFoodLogs();
  }

  Future<void> _fetchFoodLogs() async {
    setState(() => _isLoading = true);
    try {
      final result = await _supabaseService.fetchTodayData(_todayStr);
      if (mounted) {
        setState(() {
          _foodLogs = result.foodLogs;
        });
      }
    } catch (e) {
      debugPrint("讀取食物紀錄失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFoodLog(FoodLog foodLog) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newLog = await _supabaseService.addFoodLog(foodLog);
      setState(() {
        _foodLogs.insert(0, newLog);
      });
      widget.onDataChanged?.call();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('🥗 已成功紀錄「${foodLog.foodName}」(${foodLog.calories} kcal)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('新增飲食失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFoodLog(FoodLog foodLog, int index) async {
    if (foodLog.id == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final previousList = List<FoodLog>.from(_foodLogs);
    setState(() {
      _foodLogs.removeAt(index);
    });

    try {
      await _supabaseService.deleteFoodLog(foodLog.id!);
      widget.onDataChanged?.call();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('🗑️ 已刪除「${foodLog.foodName ?? "食物紀錄"}」'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _foodLogs = previousList);
        messenger.showSnackBar(
          SnackBar(content: Text('刪除失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddFoodDialog() {
    showDialog(
      context: context,
      builder: (context) => AddFoodDialog(
        dateStr: _todayStr,
        onAdd: _addFoodLog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCalories = _foodLogs.fold<int>(0, (sum, item) => sum + item.calories);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日飲食明細', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFoodLogs,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFoodDialog,
        icon: const Icon(Icons.add),
        label: const Text('記錄飲食'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFoodLogs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 熱量總計卡片
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade600, Colors.deepOrange.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔥 今日已攝取總熱量',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$totalCalories',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('kcal', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const Spacer(),
                              Text(
                                '${_foodLogs.length} 筆紀錄',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      '🍽️ 餐點內容與明細',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (_foodLogs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.no_meals, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              '今天尚未記錄任何食物點擊右下角「紀錄飲食」開始記錄！',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _foodLogs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _foodLogs[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Icon(Icons.restaurant, color: Colors.orange.shade800),
                              ),
                              title: Text(
                                item.foodName ?? '未命名食物',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+${item.calories} kcal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.deepOrange.shade700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deleteFoodLog(item, index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 80), // 為 FAB 預留空間
                  ],
                ),
              ),
            ),
    );
  }
}
