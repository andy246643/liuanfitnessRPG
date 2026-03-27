import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rpg_character.dart';
import 'muscle_group_classifier.dart';

class EnergyService {
  static final _supabase = Supabase.instance.client;

  // --- 能量計算 ---

  /// 計算單一動作的能量（每組完成率加總，封頂100%）
  static int calculateExerciseEnergy(List<Map<String, dynamic>> sets) {
    double sum = 0;
    for (final s in sets) {
      final rateStr = (s['rate'] ?? '0%').toString().replaceAll('%', '');
      final rate = (double.tryParse(rateStr) ?? 0) / 100.0;
      sum += min(rate, 1.0); // 封頂 100%
    }
    return sum.floor();
  }

  /// 計算一致性加成倍率
  static double streakMultiplier(int streakDays) {
    if (streakDays >= 30) return 2.5;
    if (streakDays >= 14) return 2.0;
    if (streakDays >= 7) return 1.5;
    if (streakDays >= 3) return 1.2;
    return 1.0;
  }

  /// 計算整場訓練的能量及屬性分配
  /// [exerciseLogs] 每個動作的 {exercise_name, sets, muscle_group?, secondary_muscle_group?}
  /// [isCoachPlan] 是否為教練指派的課表
  /// [streakDays] 連續訓練天數
  static EnergyResult calculateSessionEnergy({
    required List<ExerciseEnergyInput> exerciseLogs,
    required bool isCoachPlan,
    required int streakDays,
  }) {
    int rawEnergy = 0;
    final Map<String, int> attrGains = {
      '胸': 0, '背': 0, '腿': 0, '手臂': 0, '核心': 0, '心肺': 0,
    };

    for (final ex in exerciseLogs) {
      final exEnergy = calculateExerciseEnergy(ex.sets);
      rawEnergy += exEnergy;

      if (exEnergy <= 0) continue;

      // 複合動作：主/次肌群分配
      final classification = MuscleGroupClassifier.classifyCompound(
        ex.exerciseName,
        coachPrimary: ex.muscleGroup,
        coachSecondary: ex.secondaryMuscleGroup,
      );

      final primary = classification.primary;
      final secondary = classification.secondary;

      if (secondary != null && secondary != primary) {
        // 主 70% (ceil), 次 30% (floor)
        final primaryGain = (exEnergy * 0.7).ceil();
        final secondaryGain = (exEnergy * 0.3).floor();
        attrGains[primary] = (attrGains[primary] ?? 0) + primaryGain;
        attrGains[secondary] = (attrGains[secondary] ?? 0) + secondaryGain;
      } else {
        // 單一肌群，100% 給主肌群
        attrGains[primary] = (attrGains[primary] ?? 0) + exEnergy;
      }
    }

    // 套用加成
    final streak = streakMultiplier(streakDays);
    final coachBonus = isCoachPlan ? 1.5 : 1.0;
    final totalEnergy = (rawEnergy * streak * coachBonus).floor();

    return EnergyResult(
      rawEnergy: rawEnergy,
      streakMultiplier: streak,
      coachMultiplier: coachBonus,
      totalEnergy: totalEnergy,
      attributeGains: attrGains,
    );
  }

  // --- DB 操作 ---

  /// 載入或建立角色
  static Future<RpgCharacter> loadOrCreateCharacter(String userId) async {
    final response = await _supabase
        .from('rpg_characters')
        .select('*')
        .eq('user_id', userId)
        .limit(1);

    if (response.isNotEmpty) {
      return RpgCharacter.fromJson(response[0]);
    }

    // 建立新角色
    final newChar = await _supabase
        .from('rpg_characters')
        .insert({'user_id': userId})
        .select()
        .single();

    return RpgCharacter.fromJson(newChar);
  }

  /// 發放能量、更新屬性、處理升級
  static Future<AwardResult> awardEnergy({
    required String userId,
    required String? sessionId,
    required EnergyResult energyResult,
  }) async {
    // 1. 載入角色
    final character = await loadOrCreateCharacter(userId);

    // 2. 更新連續天數
    final today = DateTime.now().toIso8601String().substring(0, 10);
    int newStreak = character.streakDays;
    if (character.lastTrainingDate != null) {
      final lastDate = DateTime.parse(character.lastTrainingDate!);
      final diff = DateTime.now().difference(lastDate).inDays;
      if (diff == 1) {
        newStreak += 1;
      } else if (diff > 1) {
        newStreak = 1; // 斷了，重新計算
      }
      // diff == 0: 同一天，不增加
    } else {
      newStreak = 1; // 第一次訓練
    }

    // 3. 計算新的屬性值
    final gains = energyResult.attributeGains;
    final newExp = character.totalExp + energyResult.totalEnergy;

    // 4. 計算等級
    int newLevel = character.level;
    int expRemaining = newExp;
    int spent = 0;
    for (int l = 1; l <= 999; l++) {
      final needed = l * 100;
      if (spent + needed > expRemaining) {
        newLevel = l;
        break;
      }
      spent += needed;
    }

    final leveledUp = newLevel > character.level;
    final levelsGained = newLevel - character.level;

    // 5. 更新 DB
    await _supabase.from('rpg_characters').update({
      'level': newLevel,
      'total_exp': newExp,
      'current_energy': character.currentEnergy + energyResult.totalEnergy,
      'attr_chest': character.attrChest + (gains['胸'] ?? 0),
      'attr_back': character.attrBack + (gains['背'] ?? 0),
      'attr_legs': character.attrLegs + (gains['腿'] ?? 0),
      'attr_arms': character.attrArms + (gains['手臂'] ?? 0),
      'attr_core': character.attrCore + (gains['核心'] ?? 0),
      'attr_cardio': character.attrCardio + (gains['心肺'] ?? 0),
      'streak_days': newStreak,
      'last_training_date': today,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);

    // 6. 寫入 energy_log
    await _supabase.from('energy_logs').insert({
      'user_id': userId,
      'session_id': sessionId,
      'energy_earned': energyResult.totalEnergy,
      'source': 'workout',
      'details': {
        'raw_energy': energyResult.rawEnergy,
        'streak_days': newStreak,
        'streak_multiplier': energyResult.streakMultiplier,
        'coach_multiplier': energyResult.coachMultiplier,
        'attribute_gains': gains,
      },
    });

    debugPrint('RPG: +${energyResult.totalEnergy} energy, level $newLevel, streak $newStreak');

    return AwardResult(
      energyEarned: energyResult.totalEnergy,
      newLevel: newLevel,
      leveledUp: leveledUp,
      levelsGained: levelsGained,
      streakDays: newStreak,
      attributeGains: gains,
    );
  }
}

// --- Data classes ---

class ExerciseEnergyInput {
  final String exerciseName;
  final List<Map<String, dynamic>> sets;
  final String? muscleGroup;
  final String? secondaryMuscleGroup;

  ExerciseEnergyInput({
    required this.exerciseName,
    required this.sets,
    this.muscleGroup,
    this.secondaryMuscleGroup,
  });
}

class EnergyResult {
  final int rawEnergy;
  final double streakMultiplier;
  final double coachMultiplier;
  final int totalEnergy;
  final Map<String, int> attributeGains;

  EnergyResult({
    required this.rawEnergy,
    required this.streakMultiplier,
    required this.coachMultiplier,
    required this.totalEnergy,
    required this.attributeGains,
  });
}

class AwardResult {
  final int energyEarned;
  final int newLevel;
  final bool leveledUp;
  final int levelsGained;
  final int streakDays;
  final Map<String, int> attributeGains;

  AwardResult({
    required this.energyEarned,
    required this.newLevel,
    required this.leveledUp,
    required this.levelsGained,
    required this.streakDays,
    required this.attributeGains,
  });
}
