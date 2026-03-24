/// 訓練課表 Model
class WorkoutPlan {
  final String id;
  final String planName;
  final String userId;
  final bool isCompleted;
  final bool isHidden;
  final DateTime? createdAt;

  const WorkoutPlan({
    required this.id,
    required this.planName,
    required this.userId,
    this.isCompleted = false,
    this.isHidden = false,
    this.createdAt,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as String,
      planName: json['plan_name'] as String? ?? '未命名課表',
      userId: json['user_id'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? false,
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'plan_name': planName,
      'user_id': userId,
      'is_completed': isCompleted,
      'is_hidden': isHidden,
    };
    map['id'] = id;
    return map;
  }
}
