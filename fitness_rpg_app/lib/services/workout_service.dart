import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_log.dart';

/// 訓練資料服務：處理課表、訓練紀錄、身體指標的 Supabase CRUD
class WorkoutService {
  final SupabaseClient _supabase;

  WorkoutService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// 取得使用者的未完成課表
  Future<List<Map<String, dynamic>>> fetchPlans(String userId) async {
    final response = await _supabase
        .from('workout_plans')
        .select('id, plan_name')
        .eq('user_id', userId)
        .eq('is_completed', false)
        .neq('is_hidden', true)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 取得使用者的訓練紀錄（預設最近 200 筆，足夠計算統計和圖表）
  Future<List<Map<String, dynamic>>> fetchWorkoutLogs(String userId, {int limit = 200, int offset = 0}) async {
    final response = await _supabase
        .from('workout_logs')
        .select('id, plan_name, created_at, exercise_name, volume, weight, reps, sets, session_id, set_details, notes, total_rate, completion_rate')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 取得使用者的身體指標歷史（預設最近 100 筆）
  Future<List<Map<String, dynamic>>> fetchMetricsHistory(String userId, {int limit = 100}) async {
    final response = await _supabase
        .from('user_metrics_history')
        .select('weight, body_fat, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 併行取得課表、訓練紀錄、身體指標
  Future<({
    List<Map<String, dynamic>> plans,
    List<Map<String, dynamic>> logs,
    List<Map<String, dynamic>> metrics,
  })> fetchAllData(String userId) async {
    final results = await Future.wait([
      fetchPlans(userId),
      fetchWorkoutLogs(userId),
      fetchMetricsHistory(userId),
    ]);

    return (
      plans: results[0],
      logs: results[1],
      metrics: results[2],
    );
  }

  /// 取得課表的動作詳情
  Future<List<Map<String, dynamic>>> fetchPlanDetails(String planId) async {
    final response = await _supabase
        .from('plan_details')
        .select('*, rest_time_seconds, warmup_sets, prescribed_sets, alt_prescribed_sets')
        .eq('plan_id', planId)
        .order('order_index', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 軟刪除課表（設定 is_hidden = true）
  Future<void> softDeletePlan(String planId) async {
    await _supabase
        .from('workout_plans')
        .update({'is_hidden': true})
        .eq('id', planId);
  }

  /// 批量上傳訓練紀錄並標記課表完成
  ///
  /// [logs] 待上傳的訓練紀錄（含副本總結）
  /// [planId] 要標記為完成的課表 ID（可選）
  Future<void> uploadWorkoutLogs({
    required List<Map<String, dynamic>> logs,
    String? planId,
  }) async {
    final List<Future> tasks = [
      _supabase.from('workout_logs').insert(logs),
    ];

    if (planId != null && planId.isNotEmpty) {
      tasks.add(
        _supabase
            .from('workout_plans')
            .update({'is_completed': true})
            .eq('id', planId),
      );
    }

    await Future.wait(tasks);
    debugPrint('數據併行上傳成功');
  }

  /// 建立副本總結紀錄的資料結構
  static Map<String, dynamic> buildSummaryLog({
    required String userId,
    required String planName,
    required String completionRate,
    required double totalRate,
    required String notes,
    required int rpe,
    required String sessionId,
  }) {
    return {
      'user_id': userId,
      'plan_name': planName,
      'exercise_name': '🏆 副本總結結算',
      'completion_rate': completionRate,
      'total_rate': totalRate,
      'notes': notes,
      'rpe': rpe,
      'session_id': sessionId,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
