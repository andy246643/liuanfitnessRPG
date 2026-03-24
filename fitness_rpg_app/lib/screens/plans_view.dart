import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';

/// List of workout plans.
/// Extracted from _WorkoutManagerState._buildFuturePlansTab().
class PlansView extends StatelessWidget {
  final List<Map<String, dynamic>> allPlans;
  final void Function(Map<String, dynamic> plan) onStartWorkout;
  final Future<void> Function(Map<String, dynamic> plan) onDeletePlan;

  const PlansView({
    super.key,
    required this.allPlans,
    required this.onStartWorkout,
    required this.onDeletePlan,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        if (allPlans.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                isRpgMode.value ? "\u76ee\u524d\u6c92\u6709\u4efb\u4f55\u5206\u914d\u7684\u4efb\u52d9" : "\u66ab\u7121\u53ef\u9078\u8a08\u756b",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: fFam, color: dimCol),
              ),
            ),
          ),
        ...allPlans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Dismissible(
              key: ValueKey(plan['id']),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                await onDeletePlan(plan);
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
              ),
              child: ZenCard(
                padding: 12,
                child: ListTile(
                  title: Text(
                    plan['plan_name'] ?? '\u672a\u547d\u540d\u8ab2\u8868',
                    style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 22),
                        onPressed: () => onDeletePlan(plan),
                        tooltip: '\u522a\u9664\u8ab2\u8868',
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color.fromRGBO(74, 246, 38, 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.play_arrow, color: pCol),
                      ),
                    ],
                  ),
                  onTap: () => onStartWorkout(plan),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
