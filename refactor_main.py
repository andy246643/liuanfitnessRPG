import re

FILE_PATH = r"c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart"

with open(FILE_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _startWorkout
# Add alt_prescribed_sets to the select query
content = content.replace(
    ".select('*, rest_time_seconds, warmup_sets, prescribed_sets')",
    ".select('*, rest_time_seconds, warmup_sets, prescribed_sets, alt_prescribed_sets')"
)

# 2. Update _enterExercise
new_enter_exercise = '''  // 點擊任務進入特定動作
  void _enterExercise(dynamic ex, int index) {
    setState(() {
      activeExercise = ex;
      activeExerciseIndex = index;
      currentRpe = 8;
      
      // 判斷目前是否正在使用替換動作
      final isAlt = ex['_is_alt'] == true;
      
      final rawPrescribed = isAlt ? ex['alt_prescribed_sets'] : ex['prescribed_sets'];
      final prescribedSets = rawPrescribed is List ? rawPrescribed : [];

      if (prescribedSets.isNotEmpty) {
        currentSets = List.generate(
          prescribedSets.length,
          (i) {
            final ps = prescribedSets[i] as Map;
            return {
              "set_num": i + 1,
              "weight": (ps['weight'] as num?)?.toDouble() ?? 0.0,
              "reps": (ps['reps'] as num?)?.toInt() ?? 0,
              "rate": "0%",
            };
          }
        );
      } else {
        int numSets = ex['_current_target_sets'] ?? ex['target_sets'] ?? 3;
        double targetWeight =
            (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
        int targetReps = ex['_current_target_reps'] ?? ex['target_reps'] ?? 0;

        currentSets = List.generate(
          numSets,
          (i) => {
            "set_num": i + 1,
            "weight": targetWeight,
            "reps": targetReps,
            "rate": "0%",
          },
        );
      }
    });
  }'''

# Replace from `  // 點擊任務進入特定動作` to `  // 啟動休息與達成率計算`
pattern_ee = re.compile(r"  // 點擊任務進入特定動作\n.*?  // 啟動休息與達成率計算", re.DOTALL)
content = pattern_ee.sub(new_enter_exercise + "\n\n  // 啟動休息與達成率計算", content)


# 3. Update _startRest
new_start_rest = '''  // 啟動休息與達成率計算
  void _startRest(int setIdx) {
    final ex = activeExercise!;
    double targetWeight =
        (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
    int targetReps = ex['_current_target_reps'] ?? ex['target_reps'] ?? 0;

    double rateValue = 0.0;
    if (targetWeight > 0) {
      double targetVol = targetWeight * targetReps;
      double actualVol =
          currentSets[setIdx]['weight'] * currentSets[setIdx]['reps'];
      rateValue = targetVol > 0 ? (actualVol / targetVol) : 1.0;
    } else {
      rateValue = targetReps > 0
          ? (currentSets[setIdx]['reps'] / targetReps)
          : 1.0;
    }
    int rate = (rateValue * 100).toInt();

    setState(() {
      currentSets[setIdx]['rate'] = "$rate%";
      lastCompletionRate = "$rate%";
    });

    int restTimeSeconds = ex['rest_time_seconds'] ?? 60;
    final isAlt = ex['_is_alt'] == true;
    final prescribedSets = (isAlt ? ex['alt_prescribed_sets'] : ex['prescribed_sets']) as List?;
    if (prescribedSets != null && setIdx < prescribedSets.length) {
      final ps = prescribedSets[setIdx] as Map?;
      if (ps != null && ps['rest_time'] != null) {
        restTimeSeconds = (ps['rest_time'] as num).toInt();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false, // 禁止點擊背景關閉
      builder: (BuildContext context) {
        return RestTimerDialog(restTimeSeconds: restTimeSeconds);
      },
    );
  }'''

pattern_sr = re.compile(r"  // 啟動休息與達成率計算\n.*?  // 單一任務完成", re.DOTALL)
content = pattern_sr.sub(new_start_rest + "\n\n  // 單一任務完成", content)

with open(FILE_PATH, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done updating main.dart")
