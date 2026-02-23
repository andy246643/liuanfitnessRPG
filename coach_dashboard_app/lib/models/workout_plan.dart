class WorkoutPlan {
  final String? id;
  final String name;
  final String userId;
  final DateTime? createdAt;

  WorkoutPlan({
    this.id,
    required this.name,
    required this.userId,
    this.createdAt,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as String?,
      name: json['plan_name'] as String? ?? json['name'] as String? ?? '未命名課表',
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'plan_name': name,
      'user_id': userId,
    };
    if (id != null) {
      map['id'] = id!;
    }
    return map;
  }
}
