/// 統計計算服務：純邏輯，不依賴 Supabase
///
/// 負責達成率計算、Volume 計算、歷史紀錄分組等。
class StatsService {
  /// 計算單組的達成率
  ///
  /// [actualWeight] 實際重量, [actualReps] 實際次數
  /// [targetWeight] 目標重量, [targetReps] 目標次數
  /// 回傳 0.0 ~ N 的比率值（1.0 = 100%）
  static double calculateSetCompletionRate({
    required double actualWeight,
    required int actualReps,
    required double targetWeight,
    required int targetReps,
  }) {
    if (targetWeight > 0) {
      final targetVol = targetWeight * targetReps;
      final actualVol = actualWeight * actualReps;
      return targetVol > 0 ? (actualVol / targetVol) : 1.0;
    } else {
      return targetReps > 0 ? (actualReps / targetReps) : 1.0;
    }
  }

  /// 計算多組的平均達成率（百分比字串，如 "85%"）
  ///
  /// [sets] 每組資料 [{weight, reps, ...}]
  /// [getTarget] 取得第 i 組的目標重量和次數
  static String calculateAverageCompletionRate({
    required List<Map<String, dynamic>> sets,
    required ({double weight, int reps}) Function(int index) getTarget,
  }) {
    if (sets.isEmpty) return '0%';

    double totalRate = 0;
    for (int i = 0; i < sets.length; i++) {
      final s = sets[i];
      final target = getTarget(i);
      totalRate += calculateSetCompletionRate(
        actualWeight: (s['weight'] as num?)?.toDouble() ?? 0,
        actualReps: (s['reps'] as num?)?.toInt() ?? 0,
        targetWeight: target.weight,
        targetReps: target.reps,
      );
    }

    final avgRate = (totalRate / sets.length) * 100;
    return '${avgRate.toStringAsFixed(0)}%';
  }

  /// 計算一組 set_details 的總訓練量 (Volume)
  ///
  /// 若 weight > 0，volume = weight × reps
  /// 若 weight == 0（徒手動作），volume = reps × 10
  static double calculateVolume(List<Map<String, dynamic>> setDetails) {
    double total = 0;
    for (final set in setDetails) {
      final w = (set['weight'] as num?)?.toDouble() ?? 0;
      final r = (set['reps'] as num?)?.toInt() ?? 0;
      total += (w > 0) ? (w * r) : (r * 10);
    }
    return total;
  }

  /// 從歷史紀錄計算總訓練量
  ///
  /// 支援兩種格式：有 set_details（詳細）和無 set_details（舊格式）
  static double calculateTotalVolume(List<Map<String, dynamic>> logs) {
    double total = 0;
    for (final log in logs) {
      if ((log['exercise_name'] ?? '').toString().contains('🏆 副本總結')) {
        continue;
      }

      final setDetails = log['set_details'] as List<dynamic>?;
      if (setDetails != null && setDetails.isNotEmpty) {
        for (final set in setDetails) {
          if (set is Map) {
            final w = (set['weight'] as num?)?.toDouble() ?? 0;
            final r = (set['reps'] as num?)?.toInt() ?? 0;
            total += (w > 0) ? (w * r) : (r * 10);
          }
        }
      } else {
        final w = (log['weight'] as num?)?.toDouble() ?? 0;
        final r = (log['reps'] as num?)?.toInt() ?? 0;
        final s = (log['sets'] as num?)?.toInt() ?? 0;
        total += ((w > 0) ? (w * r) : (r * 10)) * s;
      }
    }
    return total;
  }

  /// 每日聚合：對每個動作按日期取最大值，消除同日重複資料點
  ///
  /// 比較規則：有重量的動作取最大重量，無重量的取最大次數
  static Map<String, List<Map<String, dynamic>>> aggregateDailyMax(
    Map<String, List<Map<String, dynamic>>> rawStats,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};

    for (final entry in rawStats.entries) {
      final exerciseName = entry.key;
      final logs = entry.value;

      // 按日期分組
      final Map<String, Map<String, dynamic>> dailyMax = {};
      for (final log in logs) {
        final date = (log['created_at'] as String).substring(0, 10);
        final weight = (log['weight'] as num?)?.toDouble() ?? 0.0;
        final reps = (log['reps'] as num?)?.toDouble() ?? 0.0;

        if (!dailyMax.containsKey(date)) {
          dailyMax[date] = log;
        } else {
          final existing = dailyMax[date]!;
          final existingW = (existing['weight'] as num?)?.toDouble() ?? 0.0;
          final existingR = (existing['reps'] as num?)?.toDouble() ?? 0.0;

          // 有重量的動作比重量，無重量的比次數
          if (weight > 0 || existingW > 0) {
            if (weight > existingW) dailyMax[date] = log;
          } else {
            if (reps > existingR) dailyMax[date] = log;
          }
        }
      }

      // 按日期排序
      final sorted = dailyMax.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      result[exerciseName] = sorted.map((e) => e.value).toList();
    }

    return result;
  }

  /// 將訓練紀錄依 session 分組（用於歷史頁面）
  ///
  /// 回傳 Map:
  /// - 'sessions': List<Map> 已完成的訓練梯次
  /// - 'statsMap': Map<String, List<Map>> 按動作名稱分組的圖表資料
  static Map<String, dynamic> groupLogsBySession(List<Map<String, dynamic>> logs) {
    // 依 session_id 或 date_planName 分組
    final Map<String, List<Map<String, dynamic>>> groupedLogs = {};
    for (final log in logs) {
      final sessionId = log['session_id'];
      final dateStr = (log['created_at'] as String).substring(0, 10);
      final planName = log['plan_name'] ?? '未知課表';
      final key = sessionId != null ? sessionId.toString() : '${dateStr}_$planName';

      groupedLogs.putIfAbsent(key, () => []);
      groupedLogs[key]!.add(log);
    }

    // 只保留有副本總結的群組（已完成的訓練）
    final Map<String, Map<String, dynamic>> sessionsMap = {};
    final Map<String, List<Map<String, dynamic>>> statsMap = {};

    for (final entry in groupedLogs.entries) {
      final key = entry.key;
      final sessionLogs = entry.value;

      final isCompleted = sessionLogs.any(
        (log) => (log['exercise_name'] ?? '').toString().contains('🏆 副本總結'),
      );
      if (!isCompleted) continue;

      final summaryLog = sessionLogs.firstWhere(
        (log) => (log['exercise_name'] ?? '').toString().contains('🏆 副本總結'),
      );

      final dateStr = (summaryLog['created_at'] as String).substring(0, 10);
      final planName = summaryLog['plan_name'] ?? '未知課表';
      final totalRate = (summaryLog['total_rate'] as num?)?.toDouble();

      sessionsMap[key] = {
        'date': dateStr,
        'plan_name': planName,
        'notes': summaryLog['notes'] ?? '',
        'total_rate': totalRate,
        'logs': <Map<String, dynamic>>[],
      };

      for (final log in sessionLogs) {
        final exName = log['exercise_name'] ?? '未知名稱';
        if (exName.toString().contains('🏆 副本總結')) continue;

        final weight = (log['weight'] as num?)?.toDouble() ?? 0.0;
        final reps = (log['reps'] as num?)?.toInt() ?? 0;
        final volume = (log['volume'] as num?)?.toDouble() ?? 0.0;

        sessionsMap[key]!['logs'].add({
          'exercise_name': exName,
          'weight': weight,
          'reps': reps,
          'sets': log['sets'] ?? 0,
          'volume': volume,
          'set_details': log['set_details'],
        });

        statsMap.putIfAbsent(exName, () => []);
        statsMap[exName]!.add(log);
      }
    }

    // 排序成就資料（由舊到新）
    for (final key in statsMap.keys) {
      statsMap[key]!.sort(
        (a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
    }

    // 排序梯次（由新到舊）
    final sessionsList = sessionsMap.values.toList();
    sessionsList.sort(
      (a, b) => (b['date'] as String).compareTo(a['date'] as String),
    );

    return {
      'sessions': sessionsList,
      'statsMap': statsMap,
    };
  }
}
