import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';

/// Training quest checklist screen.
/// Extracted from _WorkoutManagerState._buildQuestLog() and _buildFinalSummary().
class TrainingScreen extends StatelessWidget {
  final String selectedPlanName;
  final List<dynamic> allExercisesInPlan;
  final Map<int, bool> exerciseCompletion;
  final Map<int, String> exerciseFinalRates;
  final void Function(dynamic ex, int index) onExerciseTap;
  final VoidCallback onBackToLobby;
  final TextEditingController noteController;
  final int currentRpe;
  final ValueChanged<int> onRpeChanged;
  final double totalSessionRate;
  final bool isUploading;
  final VoidCallback onFinishWorkout;

  const TrainingScreen({
    super.key,
    required this.selectedPlanName,
    required this.allExercisesInPlan,
    required this.exerciseCompletion,
    required this.exerciseFinalRates,
    required this.onExerciseTap,
    required this.onBackToLobby,
    required this.noteController,
    required this.currentRpe,
    required this.onRpeChanged,
    required this.totalSessionRate,
    required this.isUploading,
    required this.onFinishWorkout,
  });

  @override
  Widget build(BuildContext context) {
    bool allDone = exerciseCompletion.values.every((v) => v == true);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: dimCol),
              onPressed: onBackToLobby,
            ),
            Expanded(
              child: Text(
                (isRpgMode.value ? "\ud83c\udff0 \u526f\u672c\uff1a$selectedPlanName" : "\u7576\u524d\u8a08\u756b\uff1a$selectedPlanName"),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(allExercisesInPlan.length, (index) {
          final ex = allExercisesInPlan[index];
          bool isDone = exerciseCompletion[index] ?? false;

          bool hasAlt =
              ex['alt_exercise'] != null &&
              ex['alt_exercise'].toString().isNotEmpty;
          bool isUsingAlt = ex['_is_using_alt'] == true;

          String displayExName = isUsingAlt
              ? ex['alt_exercise']
              : (ex['exercise'] ?? '\u52d5\u4f5c');
          List<dynamic> psets = isUsingAlt
              ? (ex['alt_prescribed_sets'] ?? [])
              : (ex['prescribed_sets'] ?? []);

          int displaySets = isUsingAlt ? (ex['alt_target_sets'] ?? ex['target_sets'] ?? 0) : (ex['target_sets'] ?? 0);
          int displayReps = isUsingAlt ? (ex['alt_target_reps'] ?? ex['target_reps'] ?? 0) : (ex['target_reps'] ?? 0);
          num displayWeight = isUsingAlt ? (ex['alt_target_weight'] ?? ex['target_weight'] ?? 0) : (ex['target_weight'] ?? 0);

          if (psets.isNotEmpty) {
            displaySets = psets.length;
            displayReps = (psets[0]['reps'] as num?)?.toInt() ?? 0;
            displayWeight = (psets[0]['weight'] as num?) ?? 0;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ZenCard(
              padding: 4,
              color: isDone ? const Color.fromRGBO(76, 175, 80, 0.05) : cardBgCol,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? Colors.green : dimCol,
                      size: 28,
                    ),
                    title: Text(
                      displayExName,
                      style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold),
                    ),
                    subtitle: isDone
                        ? Text(
                            "達成率 : ${exerciseFinalRates[index] ?? '0%'}  (點擊修改)",
                            style: TextStyle(fontFamily: fFam, color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                          )
                        : Text(
                            "$displaySets 組 $displayReps 下",
                            style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 13),
                          ),
                    trailing: isDone
                        ? Icon(Icons.edit_outlined, color: dimCol, size: 20)
                        : Icon(Icons.play_arrow_rounded, color: pCol, size: 30),
                    onTap: () {
                            ex['_current_exercise_name'] = displayExName;
                            ex['_current_target_sets'] = displaySets;
                            ex['_current_target_reps'] = displayReps;
                            ex['_current_target_weight'] = displayWeight;
                            onExerciseTap(ex, index);
                          },
                  ),
                  if (!isDone && hasAlt)
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _AltSwitchButton(
                          isUsingAlt: isUsingAlt,
                          ex: ex,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        if (allDone && allExercisesInPlan.isNotEmpty)
          _buildFinalSummary(context, totalSessionRate),
      ],
    );
  }

  Widget _buildRpeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [2, 4, 6, 8, 10]
            .map(
              (val) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text("RPE $val", style: TextStyle(fontFamily: fFam, fontWeight: FontWeight.bold)),
                  selected: currentRpe == val,
                  selectedColor: const Color.fromRGBO(74, 246, 38, 0.2),
                  onSelected: (bool selected) {
                    onRpeChanged(val);
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFinalSummary(BuildContext context, double finalScore) {
    return ZenCard(
      color: const Color.fromRGBO(74, 246, 38, 0.05),
      padding: 24,
      child: Column(
        children: [
          Text(
            (isRpgMode.value ? "\ud83c\udfc6 \u4efb\u52d9\u7d50\u7b97" : "\u672c\u6b21\u8a13\u7df4\u7e3d\u7d50"),
            style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "\u7e3d\u9054\u6210\u7387: ",
                style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 16),
              ),
              Text(
                "${finalScore.toStringAsFixed(1)}%",
                style: TextStyle(fontFamily: fFam, color: Colors.orange, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "\u5168\u8ab2\u8868\u75b2\u52de\u5ea6 (RPE)\uff1a",
                style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "$currentRpe",
                style: TextStyle(fontFamily: fFam,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "1-10 \u5206\uff0c1 \u5206\u6700\u8f15\u9b06\uff0c10 \u5206\u662f\u6700\u7d2f",
            style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildRpeSelector(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text("\u9644\u8a3b\u7559\u8a00 (\u9078\u586b)", style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "\u8a18\u9304\u4eca\u5929\u7684\u611f\u60f3\u6216\u6709\u7591\u616e\u7684\u5730\u65b9...",
              hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
              filled: true,
              fillColor: isRpgMode.value ? Colors.black : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pCol,
              foregroundColor: bgCol,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: isUploading ? null : onFinishWorkout,
            child: isUploading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: bgCol, strokeWidth: 2)
                )
              : Text(
                  isRpgMode.value ? "\u4e0a\u50b3\u6578\u64da\u4e26\u56de\u6751\u838a" : "\u4e0a\u50b3\u6578\u64da",
                  style: TextStyle(fontFamily: fFam,
                    color: bgCol,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Stateful alt-switch button that manages its own toggle without needing
/// parent setState (the parent re-reads ex['_is_using_alt'] on tap).
class _AltSwitchButton extends StatefulWidget {
  final bool isUsingAlt;
  final dynamic ex;

  const _AltSwitchButton({required this.isUsingAlt, required this.ex});

  @override
  State<_AltSwitchButton> createState() => _AltSwitchButtonState();
}

class _AltSwitchButtonState extends State<_AltSwitchButton> {
  late bool _isUsingAlt;

  @override
  void initState() {
    super.initState();
    _isUsingAlt = widget.isUsingAlt;
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _isUsingAlt = !_isUsingAlt;
          widget.ex['_is_using_alt'] = _isUsingAlt;
        });
      },
      icon: Icon(Icons.swap_horiz, size: 16, color: pCol),
      label: Text(
        _isUsingAlt ? "\u5207\u63db\u56de\u539f\u52d5\u4f5c" : "\u5207\u63db\u66ff\u63db\u52d5\u4f5c",
        style: TextStyle(fontFamily: fFam, color: pCol, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: const Color.fromRGBO(74, 246, 38, 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}
