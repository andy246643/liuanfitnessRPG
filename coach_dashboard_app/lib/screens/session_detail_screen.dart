import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/info_chip.dart';

class SessionDetailScreen extends StatefulWidget {
  final String traineeId;
  final String traineeName;
  final String dateStr;
  final String planName;

  const SessionDetailScreen({
    super.key,
    required this.traineeId,
    required this.traineeName,
    required this.dateStr,
    required this.planName,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<List<Map<String, dynamic>>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchSessionLogs();
  }

  Future<List<Map<String, dynamic>>> _fetchSessionLogs() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workout_logs')
          .select('*')
          .eq('user_id', widget.traineeId)
          .eq('plan_name', widget.planName)
          .gte('created_at', '${widget.dateStr}T00:00:00.000Z')
          .lte('created_at', '${widget.dateStr}T23:59:59.999Z')
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.dateStr} ${widget.planName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text('資料讀取失敗: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
             return const Center(child: Text('當日無動作明細'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final exerciseName = log['exercise_name'] ?? '未知名稱';
              final isSummary = exerciseName.contains('🏆 副本總結');
              final volume = log['volume'] ?? 0;
              final rpe = log['rpe'] ?? 0;
              final completionRate = log['completion_rate'] ?? '';
              final timeStr = log['created_at'] != null
                  ? DateTime.parse(log['created_at']).toLocal().toString().substring(11, 16)
                  : '未知時間';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                color: isSummary ? Colors.blue.shade50 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              exerciseName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timeStr,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isSummary) ...[
                        if (log['set_details'] != null && (log['set_details'] as List).isNotEmpty) ...[
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               InfoChip(icon: Icons.monitor_heart, label: 'RPE: $rpe', color: Colors.orange),
                               InfoChip(icon: Icons.data_exploration, label: '總容量: $volume', color: Colors.purple),
                             ],
                          ),
                          const SizedBox(height: 12),
                          ...List.generate((log['set_details'] as List).length, (i) {
                             final setDetail = log['set_details'][i];
                             int setNum = setDetail['set_num'] ?? 0;
                             double weight = (setDetail['weight'] as num?)?.toDouble() ?? 0;
                             int reps = (setDetail['reps'] as num?)?.toInt() ?? 0;
                             String rate = setDetail['rate'] ?? '';
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 6.0),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   InfoChip(icon: Icons.fitness_center, label: '第 $setNum 組:   $weight kg   x   $reps 下', color: Colors.grey.shade700),
                                   InfoChip(icon: Icons.check_circle, label: rate, color: Colors.green),
                                 ],
                               ),
                             );
                          }),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InfoChip(icon: Icons.fitness_center, label: '${log['weight']} kg x ${log['reps']}'),
                              InfoChip(icon: Icons.monitor_heart, label: 'RPE: $rpe', color: Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InfoChip(icon: Icons.data_exploration, label: '總容量: $volume', color: Colors.purple),
                              InfoChip(icon: Icons.check_circle, label: '達成率: $completionRate', color: Colors.green),
                            ],
                          ),
                        ],
                        if (log['notes'] != null && log['notes'] != "無" && log['notes'] != "") ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.yellow.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📝 動作備註', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                const SizedBox(height: 4),
                                Text(log['notes'], style: TextStyle(color: Colors.orange.shade900)),
                              ],
                            ),
                          ),
                        ]
                      ] else ...[
                        Row(
                          children: [
                             InfoChip(icon: Icons.emoji_events, label: '總結達成率: $completionRate', color: Colors.orange.shade800),
                          ],
                        ),
                        if (log['notes'] != null && log['notes'] != "無" && log['notes'] != "") ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.yellow.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📝 冒險筆記', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                const SizedBox(height: 4),
                                Text(log['notes'], style: TextStyle(color: Colors.orange.shade900)),
                              ],
                            ),
                          ),
                        ]
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
