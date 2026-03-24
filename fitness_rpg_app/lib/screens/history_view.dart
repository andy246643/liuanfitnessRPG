import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';

/// Historical sessions list.
/// Extracted from _WorkoutManagerState._buildHistoryTab().
class HistoryView extends StatelessWidget {
  final List<Map<String, dynamic>> historicalSessions;

  const HistoryView({
    super.key,
    required this.historicalSessions,
  });

  @override
  Widget build(BuildContext context) {
    if (historicalSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            isRpgMode.value ? "\u6c92\u6709\u904e\u53bb\u7684\u6230\u5f79\u7d00\u9304" : "\u66ab\u7121\u6b77\u53f2\u6230\u7e3e",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fFam, color: dimCol),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: historicalSessions.length,
      itemBuilder: (context, index) {
        final session = historicalSessions[index];
        final List<Map<String, dynamic>> sessionLogs = session['logs'] ?? [];
        final String note = session['notes'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ZenCard(
            padding: 0,
            child: ExpansionTile(
              leading: Icon(Icons.history_edu, color: pCol),
              title: Text(
                session['plan_name'] ?? '\u672a\u547d\u540d\u8a08\u756b',
                style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Text(
                    session['date'] ?? '',
                    style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 12),
                  ),
                  if (session['total_rate'] != null) ...[
                    const SizedBox(width: 8),
                    Builder(builder: (ctx) {
                      final rate = (session['total_rate'] as num).toDouble();
                      final color = rate >= 80 ? Colors.green.shade600
                          : rate >= 50 ? Colors.orange.shade600
                          : Colors.red.shade400;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\u5b8c\u6210 ${rate.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                  ],
                ],
              ),
              iconColor: pCol,
              collapsedIconColor: dimCol,
              children: [
                ...sessionLogs.reversed.map((log) {
                  final exName = log['exercise_name'] ?? '\u672a\u77e5\u52d5\u4f5c';
                  final setDetails = log['set_details'] as List<dynamic>?;

                  if (setDetails != null && setDetails.isNotEmpty) {
                    return ExpansionTile(
                      title: Text(
                        exName,
                        style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 15),
                      ),
                      iconColor: pCol,
                      collapsedIconColor: Colors.grey,
                      children: setDetails.map((set) {
                        int setNum = set['set_num'] ?? 0;
                        double weight = (set['weight'] as num?)?.toDouble() ?? 0;
                        int reps = (set['reps'] as num?)?.toInt() ?? 0;
                        String rate = set['rate'] ?? '';
                        return ListTile(
                          title: Text(
                            "\u7b2c $setNum \u7d44:   $weight kg   x   $reps \u4e0b",
                            style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 13),
                          ),
                          trailing: Text(
                            rate,
                            style: TextStyle(fontFamily: fFam, color: Colors.green, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    );
                  } else {
                    final w = log['weight'] ?? 0;
                    final r = log['reps'] ?? 0;
                    final s = log['sets'] ?? 0;
                    final valueText = w > 0 ? '$w kg x $s \u7d44 x $r \u4e0b' : '$s \u7d44 x $r \u4e0b';
                    return ListTile(
                      title: Text(exName, style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 14)),
                      trailing: Text(valueText, style: TextStyle(fontFamily: fFam, color: Colors.green, fontSize: 12)),
                    );
                  }
                }),
                if (note.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    color: const Color.fromRGBO(74, 246, 38, 0.05),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "\u7d00\u9304\uff1a$note",
                            style: TextStyle(fontFamily: fFam, color: Colors.amber, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
