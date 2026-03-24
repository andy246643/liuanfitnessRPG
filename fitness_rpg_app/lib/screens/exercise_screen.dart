import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';

/// Active exercise UI with set cards and adjusters.
/// Extracted from _buildBattleMode(), _buildSetCard(), _buildAdjuster().
class ExerciseScreen extends StatelessWidget {
  final Map<dynamic, dynamic> activeExercise;
  final List<Map<String, dynamic>> currentSets;
  final String selectedPlanName;
  final VoidCallback onCompleteExercise;
  final void Function(int setIdx) onStartRest;
  final void Function(int setIdx, String key, double delta) onSetChanged;
  final TextEditingController currentExerciseNoteController;
  final VoidCallback onBack;

  const ExerciseScreen({
    super.key,
    required this.activeExercise,
    required this.currentSets,
    required this.selectedPlanName,
    required this.onCompleteExercise,
    required this.onStartRest,
    required this.onSetChanged,
    required this.currentExerciseNoteController,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: dimCol),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  "${activeExercise['_current_exercise_name'] ?? (activeExercise['_is_using_alt'] == true ? (activeExercise['alt_exercise'] ?? activeExercise['exercise']) : activeExercise['exercise'])}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: fFam,
                    color: txtCol,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: currentSets.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSetCard(i),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            controller: currentExerciseNoteController,
            style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "\u52d5\u4f5c\u5099\u8a3b (\u9078\u586b)\uff1a\u505a\u8d77\u4f86\u7684\u611f\u89ba\u5982\u4f55\uff1f",
              hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
              filled: true,
              fillColor: isRpgMode.value ? Colors.black : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pCol,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: onCompleteExercise,
              child: Text(
                (isRpgMode.value ? "\u9818\u53d6\u7d93\u9a57\u503c" : "\u5b8c\u6210\u52d5\u4f5c"),
                style: TextStyle(fontFamily: fFam,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetCard(int i) {
    return ZenCard(
      padding: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "\u7d44\u56de ${i + 1}",
                style: TextStyle(fontFamily: fFam, color: pCol, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (currentSets[i]['rate'] != "")
                Text(
                  "\u9054\u6210: ${currentSets[i]['rate']}",
                  style: TextStyle(fontFamily: fFam, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              IconButton(
                icon: Icon(Icons.timer_outlined, color: Colors.green),
                onPressed: () => onStartRest(i),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAdjuster(i, "weight", 0.5, "kg"),
              Container(width: 1, height: 30, color: dimCol.withValues(alpha: 0.2)),
              _buildAdjuster(i, "reps", 1, "\u4e0b"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdjuster(int i, String key, double delta, String unit) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.remove_circle_outline),
          onPressed: () => onSetChanged(i, key, -delta),
        ),
        Text(
          "${currentSets[i][key]}$unit",
          style: TextStyle(fontFamily: fFam, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline),
          onPressed: () => onSetChanged(i, key, delta),
        ),
      ],
    );
  }
}
