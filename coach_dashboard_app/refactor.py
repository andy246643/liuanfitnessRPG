import re

def main():
    path = r'c:\dev\liuan_fitness_rpg_flutter\coach_dashboard_app\lib\main.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the start of CoachHomePage
    start_index = content.find('class CoachHomePage extends StatefulWidget {')
    if start_index == -1:
        print("Could not find CoachHomePage start")
        return

    # Keep everything before CoachHomePage
    new_content = content[:start_index] + '''
class TraineeSessionsScreen extends StatefulWidget {
  final String traineeId;
  final String traineeName;

  const TraineeSessionsScreen({
    super.key,
    required this.traineeId,
    required this.traineeName,
  });

  @override
  State<TraineeSessionsScreen> createState() => _TraineeSessionsScreenState();
}

class _TraineeSessionsScreenState extends State<TraineeSessionsScreen> {
  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workout_logs')
          .select('id, plan_name, created_at')
          .or('user_id.eq.${widget.traineeId},user_id.eq.${widget.traineeName}')
          .order('created_at', ascending: false);
          
      final logs = List<Map<String, dynamic>>.from(response);
      final Map<String, Map<String, dynamic>> sessions = {};
      
      for (var log in logs) {
        final dateStr = (log['created_at'] as String).substring(0, 10);
        final planName = log['plan_name'] ?? '未知課表';
        final key = '${dateStr}_$planName';
        
        if (!sessions.containsKey(key)) {
          sessions[key] = {
            'date': dateStr,
            'plan_name': planName,
            'exercise_count': 1,
            'latest_time': log['created_at'],
          };
        } else {
          sessions[key]!['exercise_count'] = (sessions[key]!['exercise_count'] as int) + 1;
        }
      }
      
      final result = sessions.values.toList();
      result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return result;
      
    } catch (e) {
      throw Exception('Fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.traineeName} 的訓練日程', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text('資料讀取失敗: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.inbox, size: 60, color: Colors.grey.shade400),
                   const SizedBox(height: 16),
                   Text('目前沒有任何訓練紀錄', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                 ],
               )
             );
          }

          final sessions = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month, color: Colors.blue.shade700),
                  ),
                  title: Text(session['plan_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('${session['date']} • 包含 ${session['exercise_count']} 個動作', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SessionDetailScreen(
                          traineeId: widget.traineeId,
                          traineeName: widget.traineeName,
                          dateStr: session['date'],
                          planName: session['plan_name'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 4. 對應訓練日的動作明細
// ----------------------------------------------------------------------
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
  Future<List<Map<String, dynamic>>> _fetchSessionLogs() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workout_logs')
          .select('*')
          .or('user_id.eq.${widget.traineeId},user_id.eq.${widget.traineeName}')
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
        future: _fetchSessionLogs(),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _InfoChip(icon: Icons.fitness_center, label: '${log['weight']} kg x ${log['reps']}'),
                            _InfoChip(icon: Icons.monitor_heart, label: 'RPE: $rpe', color: Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _InfoChip(icon: Icons.data_exploration, label: '總容量: $volume', color: Colors.purple),
                            _InfoChip(icon: Icons.check_circle, label: '達成率: $completionRate', color: Colors.green),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                             _InfoChip(icon: Icons.emoji_events, label: '總結達成率: $completionRate', color: Colors.orange.shade800),
                          ],
                        ),
                        if (log['notes'] != null && log['notes'] != "無") ...[
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

// 可重複使用的小標籤組件
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
'''
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)

if __name__ == '__main__':
    main()
