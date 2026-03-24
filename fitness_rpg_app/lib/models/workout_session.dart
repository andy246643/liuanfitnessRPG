import 'workout_log.dart';

/// 訓練梯次 Model（用於歷史紀錄頁面的分組展示）
/// 代表同一個 session_id 下的所有訓練紀錄
class WorkoutSession {
  final String key;
  final String date;
  final String planName;
  final String? notes;
  final double? totalRate;
  final List<WorkoutLog> logs;

  const WorkoutSession({
    required this.key,
    required this.date,
    required this.planName,
    this.notes,
    this.totalRate,
    this.logs = const [],
  });

  /// 該梯次的動作數（不含副本總結）
  int get exerciseCount => logs.where((log) => !log.isSummary).length;

  /// 該梯次的總訓練量
  double get totalVolume {
    double total = 0;
    for (final log in logs) {
      if (log.isSummary) continue;
      if (log.setDetails.isNotEmpty) {
        for (final set in log.setDetails) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          total += (w > 0) ? (w * r) : (r * 10);
        }
      } else {
        total += (log.weight > 0) ? (log.weight * log.reps) : (log.reps * 10);
        total *= log.sets > 0 ? log.sets : 1;
      }
    }
    return total;
  }
}
