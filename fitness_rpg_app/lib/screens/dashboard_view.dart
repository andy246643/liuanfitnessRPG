import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';

/// Dashboard view with hero card and analytics.
/// Extracted from _WorkoutManagerState._buildZenDashboard().
class DashboardView extends StatelessWidget {
  final List<Map<String, dynamic>> allPlans;
  final List<Map<String, dynamic>> historicalSessions;
  final double totalVolume;
  final void Function(Map<String, dynamic> plan) onStartWorkout;

  const DashboardView({
    super.key,
    required this.allPlans,
    required this.historicalSessions,
    required this.totalVolume,
    required this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    // --- Analytics Computation ---
    // Find earliest plan (by ascending creation order -- plans are fetched desc so reverse)
    final earliestPlan = allPlans.isNotEmpty
        ? allPlans.reduce((a, b) {
            final aName = (a['plan_name'] ?? '') as String;
            final bName = (b['plan_name'] ?? '') as String;
            return aName.compareTo(bName) <= 0 ? a : b;
          })
        : null;

    // Last workout date
    String lastWorkoutLabel = '\u5c1a\u7121\u7d00\u9304';
    if (historicalSessions.isNotEmpty) {
      final lastDate = historicalSessions.first['date'] as String?;
      if (lastDate != null) {
        final d = DateTime.tryParse(lastDate);
        if (d != null) {
          final diff = DateTime.now().difference(d).inDays;
          if (diff == 0) lastWorkoutLabel = '\u4eca\u5929';
          else if (diff == 1) lastWorkoutLabel = '\u6628\u5929';
          else lastWorkoutLabel = '$diff \u5929\u524d';
        }
      }
    }

    // Monthly frequency (last 30 days)
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));
    int monthlyCount = historicalSessions.where((s) {
      final d = DateTime.tryParse(s['date'] as String? ?? '');
      return d != null && d.isAfter(cutoff);
    }).length;

    // Monthly average completion rate - use stored total_rate field
    double monthlyAvgRate = 0;
    List<double> rates = [];
    for (var s in historicalSessions) {
      final d = DateTime.tryParse(s['date'] as String? ?? '');
      if (d == null || !d.isAfter(cutoff)) continue;
      final val = (s['total_rate'] as num?)?.toDouble();
      if (val != null && val > 0) rates.add(val);
    }
    if (rates.isNotEmpty) {
      monthlyAvgRate = rates.reduce((a, b) => a + b) / rates.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          // 1. Hero Card: Earliest Plan
          ZenCard(
            color: ZenColors.sageGreen,
            padding: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("\u63a8\u85a6\u8a08\u756b", style: TextStyle(color: ZenColors.white85, fontSize: 16)),
                    Icon(Icons.fitness_center, color: ZenColors.white85, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                if (earliestPlan != null) ...[
                  Text(
                    earliestPlan['plan_name'] ?? '\u672a\u547d\u540d\u8ab2\u8868',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => onStartWorkout(earliestPlan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ZenColors.sageGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("\u7acb\u5373\u958b\u59cb"),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    "\u606d\u559c\u5df2\u5b8c\u6210\u6240\u6709\u8a13\u7df4\uff01",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "\u8acb\u597d\u597d\u4f11\u606f\u4fdd\u990a\u8eab\u9ad4 \ud83c\udf3f",
                    style: TextStyle(color: ZenColors.white85, fontSize: 17),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          const SizedBox(height: 20),

          // 2. Unified Analytics Card
          ZenCard(
            padding: 24,
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.insights_rounded, color: ZenColors.sageGreen, size: 22),
                    const SizedBox(width: 10),
                    Text("\u8a13\u7df4\u6982\u6cc1", style: TextStyle(color: ZenColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, thickness: 0.8),
                const SizedBox(height: 20),

                // Metric A: Last Workout
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: ZenColors.sageGreen10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.access_time_rounded, color: ZenColors.sageGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("\u4e0a\u6b21\u904b\u52d5", style: TextStyle(color: ZenColors.textLight, fontSize: 14)),
                        Text(lastWorkoutLabel,
                            style: TextStyle(color: ZenColors.textDark, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Metric B: Monthly Frequency
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: ZenColors.sageGreen10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.event_repeat, color: ZenColors.sageGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("\u8fd130\u5929\u904b\u52d5\u983b\u7387", style: TextStyle(color: ZenColors.textLight, fontSize: 14)),
                        Text('$monthlyCount \u6b21',
                            style: TextStyle(color: ZenColors.textDark, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Metric C: Avg Completion Rate
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: ZenColors.sageGreen10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.verified_outlined, color: ZenColors.sageGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("\u8fd130\u5929\u5e73\u5747\u5b8c\u6210\u7387", style: TextStyle(color: ZenColors.textLight, fontSize: 14)),
                          Row(
                            children: [
                              Text(
                                rates.isEmpty ? '\u5c1a\u7121\u8cc7\u6599' : '${monthlyAvgRate.toStringAsFixed(0)}%',
                                style: TextStyle(color: ZenColors.textDark, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              if (rates.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: monthlyAvgRate / 100,
                                      minHeight: 8,
                                      backgroundColor: ZenColors.sageGreen15,
                                      valueColor: AlwaysStoppedAnimation<Color>(ZenColors.sageGreen),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
