import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_log.dart';
import '../models/food_log.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// 同時並行取得每日日誌與飲食熱量
  Future<({DailyLog? dailyLog, List<FoodLog> foodLogs})> fetchTodayData(String dateStr) async {
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('diet_daily_logs')
            .select()
            .eq('date', dateStr)
            .maybeSingle(),
        _client
            .from('diet_food_logs')
            .select()
            .eq('logged_date', dateStr)
            .order('created_at', ascending: false),
      ]);

      final dailyRaw = results[0] as Map<String, dynamic>?;
      final foodRaw = results[1] as List<dynamic>;

      final dailyLog = dailyRaw != null ? DailyLog.fromJson(dailyRaw) : null;
      final foodLogs = foodRaw.map((e) => FoodLog.fromJson(e as Map<String, dynamic>)).toList();

      return (dailyLog: dailyLog, foodLogs: foodLogs);
    } catch (e) {
      debugPrint("SupabaseService 讀取資料失敗: $e");
      rethrow;
    }
  }

  /// 儲存/更新每日健康紀錄
  Future<void> upsertDailyLog(DailyLog log) async {
    try {
      await _client.from('diet_daily_logs').upsert(
            log.toJson(),
            onConflict: 'date',
          );
    } catch (e) {
      debugPrint("SupabaseService 儲存 DailyLog 失敗: $e");
      rethrow;
    }
  }

  /// 新增飲食紀錄
  Future<FoodLog> addFoodLog(FoodLog foodLog) async {
    try {
      final response = await _client
          .from('diet_food_logs')
          .insert(foodLog.toJson())
          .select()
          .single();
      return FoodLog.fromJson(response);
    } catch (e) {
      debugPrint("SupabaseService 新增 FoodLog 失敗: $e");
      rethrow;
    }
  }

  /// 刪除飲食紀錄
  Future<void> deleteFoodLog(dynamic id) async {
    try {
      await _client.from('diet_food_logs').delete().eq('id', id);
    } catch (e) {
      debugPrint("SupabaseService 刪除 FoodLog 失敗: $e");
      rethrow;
    }
  }

  /// 取得過去 N 天的每日健康數據
  Future<List<DailyLog>> fetchWeeklyLogs(String startDateStr, String endDateStr) async {
    try {
      final response = await _client
          .from('diet_daily_logs')
          .select()
          .gte('date', startDateStr)
          .lte('date', endDateStr)
          .order('date', ascending: true);

      final rawList = response as List<dynamic>;
      return rawList.map((e) => DailyLog.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("SupabaseService 讀取週紀錄失敗: $e");
      return [];
    }
  }
}
