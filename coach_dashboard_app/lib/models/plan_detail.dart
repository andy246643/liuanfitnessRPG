class PlanDetail {
  final String? id;
  final String? planId;
  final String exercise;
  final num targetWeight;
  final int targetSets;
  final int targetReps;
  final int targetRpe;
  final int restTimeSeconds;
  final int orderIndex;

  final String? altExercise;
  final num altTargetWeight;
  final int altTargetSets;
  final int altTargetReps;

  // 舊熱身組欄位（保留相容性）
  final List<Map<String, dynamic>> warmupSets;

  // 完整組別設定 [{weight, reps}, ...]，每條對應 1 組
  final List<Map<String, dynamic>> prescribedSets;

  // 替換動作的完整組別設定
  final List<Map<String, dynamic>> altPrescribedSets;

  // 肌群分類（教練手動標註）
  final String? muscleGroup;

  PlanDetail({
    this.id,
    this.planId,
    required this.exercise,
    this.targetWeight = 0,
    this.targetSets = 0,
    this.targetReps = 0,
    this.targetRpe = 0,
    this.restTimeSeconds = 60,
    required this.orderIndex,
    this.altExercise,
    this.altTargetWeight = 0,
    this.altTargetSets = 0,
    this.altTargetReps = 0,
    this.warmupSets = const [],
    this.prescribedSets = const [],
    this.altPrescribedSets = const [],
    this.muscleGroup,
  });

  // 訓練量：prescribed_sets 非空時加總每組 weight×reps；否則舊算法
  num get targetVolume {
    if (prescribedSets.isNotEmpty) {
      return prescribedSets.fold<num>(0, (sum, ps) {
        final w = (ps['weight'] as num?) ?? 0;
        final r = (ps['reps'] as num?) ?? 0;
        return sum + w * r;
      });
    }
    final mainVolume = targetWeight * targetSets * targetReps;
    final warmupVolume = warmupSets.fold<num>(0, (sum, ws) {
      final w = (ws['weight'] as num?) ?? 0;
      final r = (ws['reps'] as num?) ?? 0;
      return sum + w * r;
    });
    return mainVolume + warmupVolume;
  }

  factory PlanDetail.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw is List) {
        return raw.where((e) => e != null && e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }
    return PlanDetail(
      id: json['id'] as String?,
      planId: json['plan_id'] as String?,
      exercise: json['exercise'] as String,
      targetWeight: (json['target_weight'] as num?)?.toDouble() ?? 0,
      targetSets: json['target_sets'] as int? ?? 0,
      targetReps: json['target_reps'] as int? ?? 0,
      targetRpe: json['target_rpe'] as int? ?? 0,
      restTimeSeconds: json['rest_time_seconds'] as int? ?? 60,
      orderIndex: json['order_index'] as int? ?? 0,
      altExercise: json['alt_exercise'] as String?,
      altTargetWeight: (json['alt_target_weight'] as num?)?.toDouble() ?? 0,
      altTargetSets: json['alt_target_sets'] as int? ?? 0,
      altTargetReps: json['alt_target_reps'] as int? ?? 0,
      warmupSets: parseList(json['warmup_sets']),
      prescribedSets: parseList(json['prescribed_sets']),
      altPrescribedSets: parseList(json['alt_prescribed_sets']),
      muscleGroup: json['muscle_group'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // Strip internal Flutter-only '_id' keys before sending to Supabase
    List<Map<String, dynamic>> cleanSets(List<Map<String, dynamic>> sets) =>
        sets.map((s) {
          final m = Map<String, dynamic>.from(s);
          m.remove('_id');
          return m;
        }).toList();

    final map = <String, dynamic>{
      'exercise': exercise,
      'target_weight': targetWeight,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_rpe': targetRpe,
      'rest_time_seconds': restTimeSeconds,
      'order_index': orderIndex,
      'alt_exercise': altExercise,
      'alt_target_weight': altTargetWeight,
      'alt_target_sets': altTargetSets,
      'alt_target_reps': altTargetReps,
      'warmup_sets': cleanSets(warmupSets),
      'prescribed_sets': cleanSets(prescribedSets),
      'alt_prescribed_sets': cleanSets(altPrescribedSets),
    };
    // Only include muscle_group if it has a value — avoids errors when the
    // column doesn't yet exist in the DB (migration not yet applied).
    if (muscleGroup != null && muscleGroup!.isNotEmpty) {
      map['muscle_group'] = muscleGroup;
    }
    if (id != null) map['id'] = id!;
    if (planId != null) map['plan_id'] = planId!;
    return map;
  }

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
    String? altExercise,
    num? altTargetWeight,
    int? altTargetSets,
    int? altTargetReps,
    List<Map<String, dynamic>>? warmupSets,
    List<Map<String, dynamic>>? prescribedSets,
    List<Map<String, dynamic>>? altPrescribedSets,
    String? muscleGroup,
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
      altExercise: altExercise != null ? (altExercise.isEmpty ? null : altExercise) : this.altExercise,
      altTargetWeight: altTargetWeight ?? this.altTargetWeight,
      altTargetSets: altTargetSets ?? this.altTargetSets,
      altTargetReps: altTargetReps ?? this.altTargetReps,
      warmupSets: warmupSets ?? this.warmupSets,
      prescribedSets: prescribedSets ?? this.prescribedSets,
      altPrescribedSets: altPrescribedSets ?? this.altPrescribedSets,
      muscleGroup: muscleGroup ?? this.muscleGroup,
    );
  }

  PlanDetail cloneForNewPlan(String newPlanId, {int? newOrderIndex}) {
    return PlanDetail(
      id: null,
      planId: newPlanId,
      exercise: exercise,
      targetWeight: targetWeight,
      targetSets: targetSets,
      targetReps: targetReps,
      targetRpe: targetRpe,
      restTimeSeconds: restTimeSeconds,
      orderIndex: newOrderIndex ?? orderIndex,
      altExercise: altExercise,
      altTargetWeight: altTargetWeight,
      altTargetSets: altTargetSets,
      altTargetReps: altTargetReps,
      warmupSets: warmupSets.isNotEmpty ? List<Map<String, dynamic>>.from(warmupSets) : [],
      prescribedSets: prescribedSets.isNotEmpty ? List<Map<String, dynamic>>.from(prescribedSets) : [],
      altPrescribedSets: altPrescribedSets.isNotEmpty ? List<Map<String, dynamic>>.from(altPrescribedSets) : [],
      muscleGroup: muscleGroup,
    );
  }
}
