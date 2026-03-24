/// 訓練紀錄 Model（對應 workout_logs 資料表）
class WorkoutLog {
  final String? id;
  final String userId;
  final String planName;
  final String exerciseName;
  final double weight;
  final int reps;
  final int sets;
  final double volume;
  final String? sessionId;
  final List<Map<String, dynamic>> setDetails;
  final String? notes;
  final String? completionRate;
  final double? totalRate;
  final int? rpe;
  final DateTime createdAt;

  const WorkoutLog({
    this.id,
    required this.userId,
    required this.planName,
    required this.exerciseName,
    this.weight = 0,
    this.reps = 0,
    this.sets = 0,
    this.volume = 0,
    this.sessionId,
    this.setDetails = const [],
    this.notes,
    this.completionRate,
    this.totalRate,
    this.rpe,
    required this.createdAt,
  });

  /// 是否為副本總結紀錄
  bool get isSummary => exerciseName.contains('🏆 副本總結');

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '未知課表',
      exerciseName: json['exercise_name'] as String? ?? '未知動作',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      sets: (json['sets'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      sessionId: json['session_id'] as String?,
      setDetails: _parseSetDetails(json['set_details']),
      notes: json['notes'] as String?,
      completionRate: json['completion_rate'] as String?,
      totalRate: (json['total_rate'] as num?)?.toDouble(),
      rpe: json['rpe'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  static List<Map<String, dynamic>> _parseSetDetails(dynamic raw) {
    if (raw is List) {
      return raw
          .where((e) => e != null && e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'plan_name': planName,
      'exercise_name': exerciseName,
      'weight': weight,
      'reps': reps,
      'sets': sets,
      'volume': volume,
      'session_id': sessionId,
      'set_details': setDetails,
      'notes': notes,
      'completion_rate': completionRate,
      'total_rate': totalRate,
      'rpe': rpe,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id!;
    return map;
  }
}
