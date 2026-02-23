class PlanDetail {
  final String? id;
  final String? planId; // Changed to nullable in case it's a new unsaved plan
  final String exercise;
  final num targetWeight;
  final int targetSets;
  final int targetReps;
  final int targetRpe;
  final int restTimeSeconds;
  final int orderIndex; // 加入 order_index 確保動作順序

  PlanDetail({
    this.id,
    this.planId,
    required this.exercise,
    this.targetWeight = 0,
    this.targetSets = 0,
    this.targetReps = 0,
    this.targetRpe = 0,
    this.restTimeSeconds = 60, // 預設 60 秒休息
    required this.orderIndex,
  });

  // 自動計算總訓練量
  num get targetVolume => targetWeight * targetSets * targetReps;

  factory PlanDetail.fromJson(Map<String, dynamic> json) {
    return PlanDetail(
      id: json['id'] as String?,
      planId: json['plan_id'] as String?,
      exercise: json['exercise'] as String,
      targetWeight: json['target_weight'] as num? ?? 0,
      targetSets: json['target_sets'] as int? ?? 0,
      targetReps: json['target_reps'] as int? ?? 0,
      targetRpe: json['target_rpe'] as int? ?? 0,
      restTimeSeconds: json['rest_time_seconds'] as int? ?? 60,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'exercise': exercise,
      'target_weight': targetWeight,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_rpe': targetRpe,
      'rest_time_seconds': restTimeSeconds,
      'order_index': orderIndex,
    };
    if (id != null) {
      map['id'] = id!;
    }
    if (planId != null) {
      map['plan_id'] = planId!;
    }
    return map;
  }

  // 用於編輯時複製自身並修改屬性，方便狀態管理
  PlanDetail copyWith({
    String? id,
    String? planId,
    String? exercise,
    num? targetWeight,
    int? targetSets,
    int? targetReps,
    int? targetRpe,
    int? restTimeSeconds,
    int? orderIndex,
  }) {
    return PlanDetail(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      exercise: exercise ?? this.exercise,
      targetWeight: targetWeight ?? this.targetWeight,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetRpe: targetRpe ?? this.targetRpe,
      restTimeSeconds: restTimeSeconds ?? this.restTimeSeconds,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  // Helper method to create a clone for a new plan (clears IDs)
  PlanDetail cloneForNewPlan(String newPlanId, {int? newOrderIndex}) {
    return PlanDetail(
      id: null, // Clear original ID
      planId: newPlanId, // Set to new plan ID
      exercise: exercise,
      targetWeight: targetWeight,
      targetSets: targetSets,
      targetReps: targetReps,
      targetRpe: targetRpe,
      restTimeSeconds: restTimeSeconds,
      orderIndex: newOrderIndex ?? orderIndex,
    );
  }
}
