import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// 教練端資料服務：處理教練、學員、訓練統計的 Supabase CRUD
class CoachService {
  final SupabaseClient _supabase;
  static const _uuid = Uuid();

  CoachService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ─── 教練驗證 ───

  /// 教練登入：回傳教練資料，若找不到回傳 null
  Future<Map<String, dynamic>?> loginCoach(String name) async {
    final response = await _supabase
        .from('users')
        .select('*')
        .ilike('name', name)
        .eq('role', 'coach')
        .limit(1);

    return response.isNotEmpty ? response[0] : null;
  }

  /// 註冊新教練：檢查名稱是否重複，成功回傳新教練資料
  Future<Map<String, dynamic>> registerCoach(String name) async {
    if (name.isEmpty) {
      throw CoachServiceException('請先輸入想要註冊的教練名稱');
    }

    // 檢查是否已有同名教練
    final existing = await _supabase
        .from('users')
        .select('id')
        .ilike('name', name)
        .eq('role', 'coach')
        .limit(1);

    if (existing.isNotEmpty) {
      throw CoachServiceException('名稱已被使用！請更換一個名稱重新註冊。');
    }

    final insertResponse = await _supabase.from('users').insert({
      'name': name,
      'role': 'coach',
    }).select();

    if (insertResponse.isEmpty) {
      throw CoachServiceException('註冊失敗，請稍後再試。');
    }

    return insertResponse[0];
  }

  // ─── 學員管理 ───

  /// 取得教練旗下所有學員
  Future<List<Map<String, dynamic>>> fetchTrainees(String coachId) async {
    final response = await _supabase
        .from('users')
        .select('id, name, created_at')
        .eq('role', 'trainee')
        .eq('coach_id', coachId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 建立新學員（使用正確的 UUID 生成）
  Future<void> createTrainee({
    required String name,
    required String coachId,
  }) async {
    final newId = _uuid.v4();

    await _supabase.from('users').insert({
      'id': newId,
      'name': name,
      'role': 'trainee',
      'coach_id': coachId,
    });

    debugPrint('新學員已建立: $name (ID: $newId)');
  }

  // ─── 訓練統計 ───

  /// 取得學員近 4 週訓練統計（頻率 + 平均完成率）
  Future<Map<String, dynamic>> fetchRecentTrainingStats(String traineeId) async {
    try {
      final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));
      final isoDateStr = fourWeeksAgo.toIso8601String();

      final response = await _supabase
          .from('workout_logs')
          .select('id, created_at, total_rate')
          .eq('user_id', traineeId)
          .eq('exercise_name', '🏆 副本總結結算')
          .gte('created_at', isoDateStr)
          .order('created_at', ascending: true);

      final logs = List<Map<String, dynamic>>.from(response);

      final Set<String> uniqueDays = {};
      double totalRateSum = 0;

      for (final log in logs) {
        final date = (log['created_at'] as String).substring(0, 10);
        uniqueDays.add(date);
        totalRateSum += (log['total_rate'] as num?)?.toDouble() ?? 0.0;
      }

      final avgRate = logs.isEmpty ? 0.0 : totalRateSum / logs.length;

      return {
        'frequency': uniqueDays.length,
        'completion_rate': avgRate,
      };
    } catch (e) {
      debugPrint('Fetch stats error: $e');
      return {'frequency': 0, 'completion_rate': 0.0};
    }
  }

  /// 取得學員各動作的成績統計（每日最大值聚合，預設最近 300 筆）
  Future<Map<String, List<Map<String, dynamic>>>> fetchExerciseStats(String traineeId, {int limit = 300}) async {
    final response = await _supabase
        .from('workout_logs')
        .select('id, created_at, exercise_name, weight, reps')
        .eq('user_id', traineeId)
        .neq('exercise_name', '🏆 副本總結結算')
        .order('created_at', ascending: true)
        .limit(limit);

    final logs = List<Map<String, dynamic>>.from(response);
    final Map<String, List<Map<String, dynamic>>> stats = {};

    for (final log in logs) {
      final exName = log['exercise_name'] as String? ?? '未知動作';
      stats.putIfAbsent(exName, () => []);
      stats[exName]!.add(log);
    }

    // 每日最大值聚合
    final Map<String, List<Map<String, dynamic>>> dailyMaxStats = {};
    for (final entry in stats.entries) {
      final Map<String, Map<String, dynamic>> dailyMaxMap = {};

      for (final log in entry.value) {
        final date = (log['created_at'] as String).substring(0, 10);
        final currentWeight = (log['weight'] as num?)?.toDouble() ?? 0;
        final currentReps = (log['reps'] as num?)?.toInt() ?? 0;

        if (!dailyMaxMap.containsKey(date)) {
          dailyMaxMap[date] = log;
        } else {
          final prevWeight = (dailyMaxMap[date]!['weight'] as num?)?.toDouble() ?? 0;
          final prevReps = (dailyMaxMap[date]!['reps'] as num?)?.toInt() ?? 0;

          if (currentWeight > 0) {
            if (currentWeight > prevWeight) dailyMaxMap[date] = log;
          } else {
            if (currentReps > prevReps) dailyMaxMap[date] = log;
          }
        }
      }

      dailyMaxStats[entry.key] = dailyMaxMap.values.toList()
        ..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    }

    return dailyMaxStats;
  }

  /// 取得學員的訓練歷史（按日期+課表分組）
  Future<List<Map<String, dynamic>>> fetchHistorySessions(String traineeId, {int limit = 200}) async {
    final response = await _supabase
        .from('workout_logs')
        .select('id, plan_name, created_at, total_rate, exercise_name')
        .eq('user_id', traineeId)
        .order('created_at', ascending: false)
        .limit(limit);

    final logs = List<Map<String, dynamic>>.from(response);
    final Map<String, Map<String, dynamic>> sessions = {};

    for (final log in logs) {
      final dateStr = (log['created_at'] as String).substring(0, 10);
      final planName = log['plan_name'] ?? '未知課表';
      final key = '${dateStr}_$planName';

      sessions.putIfAbsent(key, () => {
        'date': dateStr,
        'plan_name': planName,
        'exercise_count': 0,
        'latest_time': log['created_at'],
        'total_rate': null,
      });

      if ((log['exercise_name'] as String?)?.contains('副本總結') == true) {
        sessions[key]!['total_rate'] = log['total_rate'];
      } else {
        sessions[key]!['exercise_count'] = (sessions[key]!['exercise_count'] as int) + 1;
      }
    }

    final result = sessions.values.toList();
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return result;
  }

  /// 取得學員的排程課表（含動作詳情）
  Future<List<Map<String, dynamic>>> fetchScheduledPlans(String traineeId) async {
    final response = await _supabase
        .from('workout_plans')
        .select('id, plan_name, created_at, plan_details(id, exercise, target_sets, target_reps, target_weight, order_index, prescribed_sets)')
        .eq('user_id', traineeId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 取得特定日期 + 課表的訓練紀錄詳情
  Future<List<Map<String, dynamic>>> fetchSessionLogs({
    required String traineeId,
    required String planName,
    required String dateStr,
  }) async {
    final response = await _supabase
        .from('workout_logs')
        .select('*')
        .eq('user_id', traineeId)
        .eq('plan_name', planName)
        .gte('created_at', '${dateStr}T00:00:00.000Z')
        .lte('created_at', '${dateStr}T23:59:59.999Z')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}

/// 教練服務例外
class CoachServiceException implements Exception {
  final String message;
  const CoachServiceException(this.message);

  @override
  String toString() => message;
}
