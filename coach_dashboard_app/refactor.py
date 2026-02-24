import sys

file_path = r'c:\dev\liuan_fitness_rpg_flutter\coach_dashboard_app\lib\main.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "// ----------------------------------------------------------------------\n// 3. 單一學員專屬訓練動態 (原本的 Dashboard)\n// ----------------------------------------------------------------------"
end_marker = "// ----------------------------------------------------------------------\n// 4. 對應訓練日的動作明細\n// ----------------------------------------------------------------------"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("Markers not found!")
    sys.exit(1)

new_code = """// ----------------------------------------------------------------------
// 3. 單一學員專屬管理面版 (Dashboard)
// ----------------------------------------------------------------------

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

class _TraineeSessionsScreenState extends State<TraineeSessionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Tab 3: History (Original Logic) ---
  Future<List<Map<String, dynamic>>> _fetchHistorySessions() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workout_logs')
          .select('id, plan_name, created_at')
          .eq('user_id', widget.traineeId)
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

  // --- Tab 2: Scheduled Plans ---
  Future<List<Map<String, dynamic>>> _fetchScheduledPlans() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workout_plans')
          .select('id, plan_name, created_at')
          .eq('user_id', widget.traineeId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Soft light blue-grey background
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade800,
              child: Text(widget.traineeName.isNotEmpty ? widget.traineeName.substring(0, 1).toUpperCase() : '?'),
            ),
            const SizedBox(width: 12),
            Text(widget.traineeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: Colors.blue.shade700,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '學員資訊'),
            Tab(text: '課表安排'),
            Tab(text: '訓練紀錄'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildScheduleTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlanScreen(
                traineeId: widget.traineeId,
                traineeName: widget.traineeName,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新增課表', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E5EFF), // Bright modern blue
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // === 1. 學員資訊 Tab ===
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 關鍵指標卡片
          _buildMetricCard(
            title: '目前體重 (Weight)',
            value: '72.5 kg',
            trend: '-1.2% vs 上個月',
            trendColor: Colors.green,
            icon: Icons.monitor_weight_outlined,
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: '體脂率 (Fat)',
                  value: '18.4 %',
                  trend: '-0.5%',
                  trendColor: Colors.green,
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.purple,
                  iconBgColor: Colors.purple.shade50,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: '骨骼肌 (Muscle)',
                  value: '34.2 kg',
                  trend: '+0.8%',
                  trendColor: Colors.green,
                  icon: Icons.fitness_center,
                  iconColor: Colors.orange,
                  iconBgColor: Colors.orange.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 圖表替代佔位卡片
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('近三個月體態趨勢', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMockBar(80, Colors.grey.shade300, '1月'),
                      _buildMockBar(70, Colors.blue.shade200, '2月'),
                      _buildMockBar(95, const Color(0xFF1E5EFF), '3月'), // Main active bar
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBar(double height, Color color, String label) {
    return Column(
      children: [
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String trend,
    required Color trendColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.black87)),
            const SizedBox(height: 8),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: trendColor.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Text(trend, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // === 2. 課表安排 Tab ===
  Widget _buildScheduleTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchScheduledPlans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text('載入失敗: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return _buildEmptyState(Icons.event_note, '目前沒有安排任何課表');
        }

        final plans = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final dateStr = (plan['created_at'] as String?)?.substring(0, 10) ?? '未知日期';
            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment, color: Colors.blue.shade700),
                ),
                title: Text(plan['plan_name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('安排/建立日期: $dateStr', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                trailing: TextButton(
                  onPressed: () {
                     // 未來可以跳轉至課表編輯或預覽頁面
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('點擊了課表: ${plan['plan_name']}')),
                     );
                  },
                  child: const Text('查看', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // === 3. 課表內容 (歷史紀錄) Tab ===
  Widget _buildHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchHistorySessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text('載入失敗: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return _buildEmptyState(Icons.history, '目前沒有任何訓練紀錄');
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
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle_outline, color: Colors.purple.shade700),
                ),
                title: Text(session['plan_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('${session['date']} • 完成 ${session['exercise_count']} 個動作', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
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
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      )
    );
  }
}
\n"""

content = content[:start_idx] + new_code + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated TraineeSessionsScreen.")
