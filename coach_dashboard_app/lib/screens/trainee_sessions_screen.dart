import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'create_plan_screen.dart';
import 'session_detail_screen.dart';
import 'plan_editor_screen.dart';
import '../models/workout_plan.dart';
import '../services/muscle_group_classifier.dart';

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

  // --- 新增：取得 4 週訓練狀況 ---
  Future<Map<String, dynamic>> _fetchRecentTrainingStats() async {
    try {
      final supabase = Supabase.instance.client;
      // 往前推算 28 天 (4 週)
      final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));
      final isoDateStr = fourWeeksAgo.toIso8601String();

      final response = await supabase
          .from('workout_logs')
          .select('id, created_at, total_rate')
          .eq('user_id', widget.traineeId)
          .eq('exercise_name', '🏆 副本總結結算') // 篩選只有結算的紀錄
          .gte('created_at', isoDateStr)
          .order('created_at', ascending: true);

      final logs = List<Map<String, dynamic>>.from(response);

      // 計算訓練頻率 (天數)
      Set<String> uniqueDays = {};
      double totalRateSum = 0;

      for (var log in logs) {
        String date = (log['created_at'] as String).substring(0, 10);
        uniqueDays.add(date);

        // 累計完成率，如果為空則視為 0
        totalRateSum += (log['total_rate'] as num?)?.toDouble() ?? 0.0;
      }

      double avgCompletionRate = logs.isEmpty ? 0 : totalRateSum / logs.length;

      return {
        'frequency': uniqueDays.length,
        'completion_rate': avgCompletionRate,
      };
    } catch (e) {
      debugPrint('Fetch stats error: $e');
      return {'frequency': 0, 'completion_rate': 0.0};
    }
  }

  // --- 新增：各項動作紀錄 (Chart 數據) ---
  Map<String, List<Map<String, dynamic>>> achievementStats = {};
  String? selectedAchievementExercise;
  bool _isLoadingStats = true;

  Future<void> _fetchExerciseStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workout_logs')
          .select('id, created_at, exercise_name, weight, reps')
          .eq('user_id', widget.traineeId)
          .neq('exercise_name', '🏆 副本總結結算')
          .order('created_at', ascending: true)
          .limit(300);

      final logs = List<Map<String, dynamic>>.from(response);
      Map<String, List<Map<String, dynamic>>> stats = {};

      for (var log in logs) {
        String exName = log['exercise_name'] ?? '未知動作';
        if (!stats.containsKey(exName)) {
          stats[exName] = [];
        }
        stats[exName]!.add(log);
      }

      // 將每個動作每天的多筆紀錄縮減為一筆（取每日最大重量或最大次數作為代表）
      Map<String, List<Map<String, dynamic>>> dailyMaxStats = {};
      for (var entry in stats.entries) {
         Map<String, Map<String, dynamic>> dailyMaxMap = {};
         for (var log in entry.value) {
            String date = (log['created_at'] as String).substring(0, 10);
            double currentWeight = (log['weight'] as num?)?.toDouble() ?? 0;
            int currentReps = (log['reps'] as num?)?.toInt() ?? 0;

            if (!dailyMaxMap.containsKey(date)) {
               dailyMaxMap[date] = log;
            } else {
               double prevWeight = (dailyMaxMap[date]!['weight'] as num?)?.toDouble() ?? 0;
               int prevReps = (dailyMaxMap[date]!['reps'] as num?)?.toInt() ?? 0;

               // 如果有重量，比重量。如果沒重量，比次數。
               if (currentWeight > 0) {
                 if (currentWeight > prevWeight) {
                    dailyMaxMap[date] = log;
                 }
               } else {
                 if (currentReps > prevReps) {
                    dailyMaxMap[date] = log;
                 }
               }
            }
         }
         dailyMaxStats[entry.key] = dailyMaxMap.values.toList()..sort((a,b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
      }

      if (mounted) {
        setState(() {
          achievementStats = dailyMaxStats;
          // 設定預設選取的動作
          if (achievementStats.isNotEmpty) {
            final keys = achievementStats.keys.toList();
            // Try to find a common compound lift, else pick the first
            if (keys.contains('深蹲')) {
              selectedAchievementExercise = '深蹲';
            } else if (keys.contains('硬舉')) {
              selectedAchievementExercise = '硬舉';
            } else {
              selectedAchievementExercise = keys.first;
            }
          }
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch exercise stats err: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('載入動作統計失敗，請稍後再試'), backgroundColor: Colors.red),
        );
      }
    }
  }

  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _plansFuture;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchExerciseStats(); // 頁面載入時先抓圖表數據
    _statsFuture = _fetchRecentTrainingStats();
    _plansFuture = _fetchScheduledPlans();
    _historyFuture = _fetchHistorySessions();
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
          .select('id, plan_name, created_at, total_rate, exercise_name')
          .eq('user_id', widget.traineeId)
          .order('created_at', ascending: false)
          .limit(200);

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
            'exercise_count': 0,
            'latest_time': log['created_at'],
            'total_rate': null,
          };
        }

        // 如果是副本總結結算，載入 total_rate
        if ((log['exercise_name'] as String?)?.contains('副本總結') == true) {
          sessions[key]!['total_rate'] = log['total_rate'];
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
          .select('id, plan_name, user_id, created_at, plan_details(id, exercise, target_sets, target_reps, target_weight, order_index, prescribed_sets)')
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
          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlanScreen(
                traineeId: widget.traineeId,
                traineeName: widget.traineeName,
              ),
            ),
          ).then((saved) {
            if (saved == true && mounted) {
              setState(() { _plansFuture = _fetchScheduledPlans(); });
            }
          });
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
  // === 1. 學員資訊 Tab ===
  Widget _buildInfoTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'frequency': 0, 'completion_rate': 0.0};
        final frequency = stats['frequency'] as int;
        final completionRate = stats['completion_rate'] as double;
        final completionStr = '${completionRate.toStringAsFixed(1)}%';

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Personal Information 卡片
              _buildSectionCard(
                title: 'Personal Information',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildInfoItem('Full Name', widget.traineeName)),
                        Expanded(child: _buildInfoItem('Role', 'Trainee')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildInfoItem('Trainee ID', widget.traineeId.substring(0, min(8, widget.traineeId.length)))),
                        Expanded(child: _buildInfoItem('Status', 'Active', highlight: true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. 近期訓練狀況 (Biometrics style card)
              _buildSectionCard(
                title: 'Recent Training (4 Weeks)',
                actionWidget: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                content: Row(
                  children: [
                    Expanded(
                      child: _buildMetricBox(
                        value: frequency.toString(),
                        label: 'Days Trained',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricBox(
                        value: completionStr,
                        label: 'Avg. Completion',
                        valueColor: completionRate >= 80 ? Colors.green.shade700 : (completionRate > 0 ? Colors.orange.shade700 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. 各項動作紀錄 (Chart Section)
              _buildSectionCard(
                title: 'Exercise Records Growth',
                actionWidget: const Icon(Icons.trending_up, color: Colors.green, size: 20),
                content: _buildAchievementChartSection(),
              ),
              const SizedBox(height: 40), // 底部留白避免遮擋
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({required String title, required Widget content, Widget? actionWidget}) {
    return Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
                if (actionWidget != null)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                     child: actionWidget,
                   ),
              ],
            ),
            const SizedBox(height: 20),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: highlight ? Colors.green.shade700 : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({required String value, required String label, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: valueColor ?? const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  // 分類卡片展開狀態
  final Map<String, bool> _coachExpandedGroups = {};
  final Map<String, String?> _coachSelectedExercise = {};

  Widget _buildAchievementChartSection() {
    if (_isLoadingStats) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (achievementStats.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text("沒有足夠的動作數據", style: TextStyle(color: Colors.grey))),
      );
    }

    final grouped = MuscleGroupClassifier.groupExercises(achievementStats.keys);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: grouped.entries.map((entry) {
        final groupName = entry.key;
        final exercises = entry.value;
        final isExpanded = _coachExpandedGroups[groupName] ?? false;
        final selected = _coachSelectedExercise[groupName] ?? exercises.first;
        final iconWidget = MuscleGroupClassifier.buildIcon(groupName, size: 22);
        final progress = _calcGroupProgress(exercises);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 標頭
              InkWell(
                onTap: () => setState(() => _coachExpandedGroups[groupName] = !isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(exercises.join('、'), style: TextStyle(color: Colors.grey.shade500, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (progress != null) _buildCoachProgressBadge(progress),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('${exercises.length}', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              // 展開圖表
              if (isExpanded) ...[
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
                      if (exercises.length > 1)
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: exercises.map((ex) {
                              final isSel = ex == selected;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(ex, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.black87)),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF10B981),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                                  onSelected: (_) => setState(() => _coachSelectedExercise[groupName] = ex),
                                  visualDensity: VisualDensity.compact,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      if (exercises.length > 1) const SizedBox(height: 10),
                      _buildCoachExerciseChart(selected),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCoachExerciseChart(String exerciseName) {
    final chartData = achievementStats[exerciseName] ?? [];
    if (chartData.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text("此項目無有效數據", style: TextStyle(color: Colors.grey))));
    }

    List<FlSpot> spots = [];
    double maxVol = 0;
    bool hasWeight = false;
    for (int i = 0; i < chartData.length; i++) {
      double weight = (chartData[i]['weight'] as num?)?.toDouble() ?? 0.0;
      double reps = (chartData[i]['reps'] as num?)?.toDouble() ?? 0.0;
      double yValue = weight > 0 ? weight : reps;
      if (weight > 0) hasWeight = true;
      spots.add(FlSpot(i.toDouble(), yValue));
      if (yValue > maxVol) maxVol = yValue;
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, _) => Text(val.toInt().toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 10)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 22,
                  interval: max(1, (spots.length / 6).floor().toDouble()),
                  getTitlesWidget: (value, _) {
                    int idx = value.toInt();
                    if (idx >= 0 && idx < chartData.length) {
                      final d = chartData[idx]['created_at'] as String?;
                      if (d != null && d.length >= 10) return Padding(padding: const EdgeInsets.only(top: 5), child: Text(d.substring(5, 10).replaceFirst('-', '/'), style: TextStyle(color: Colors.grey.shade500, fontSize: 9)));
                    }
                    return const SizedBox.shrink();
                  },
                )),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0, maxX: max(spots.length.toDouble() - 1, 1), minY: 0, maxY: maxVol * 1.2,
              lineBarsData: [
                LineChartBarData(spots: spots, isCurved: true, color: const Color(0xFF10B981), barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: const Color(0x2610B981))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(hasWeight ? "單位：kg（重量）" : "單位：次（次數）", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
      ],
    );
  }

  ({double delta, bool hasWeight})? _calcGroupProgress(List<String> exercises) {
    for (final ex in exercises) {
      final data = achievementStats[ex];
      if (data == null || data.length < 2) continue;
      final firstW = (data.first['weight'] as num?)?.toDouble() ?? 0.0;
      final lastW = (data.last['weight'] as num?)?.toDouble() ?? 0.0;
      final firstR = (data.first['reps'] as num?)?.toDouble() ?? 0.0;
      final lastR = (data.last['reps'] as num?)?.toDouble() ?? 0.0;
      if (firstW > 0 || lastW > 0) return (delta: lastW - firstW, hasWeight: true);
      return (delta: lastR - firstR, hasWeight: false);
    }
    return null;
  }

  Widget _buildCoachProgressBadge(({double delta, bool hasWeight}) p) {
    final unit = p.hasWeight ? 'kg' : '次';
    Color c; IconData ic; String t;
    if (p.delta > 0.5) { c = Colors.green; ic = Icons.arrow_upward; t = '+${p.delta.toStringAsFixed(p.hasWeight ? 1 : 0)}$unit'; }
    else if (p.delta < -0.5) { c = Colors.red; ic = Icons.arrow_downward; t = '${p.delta.toStringAsFixed(p.hasWeight ? 1 : 0)}$unit'; }
    else { c = Colors.grey; ic = Icons.arrow_forward; t = '維持'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 12, color: c), const SizedBox(width: 2),
        Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // === 2. 課表安排 Tab ===
  Widget _buildScheduleTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _plansFuture = _fetchScheduledPlans(); });
        await _plansFuture;
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _plansFuture,
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
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final dateStr = (plan['created_at'] as String?)?.substring(0, 10) ?? '未知日期';
            final details = List<Map<String, dynamic>>.from(plan['plan_details'] as List? ?? []);
            details.sort((a, b) => ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0));

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment, color: Colors.blue.shade700),
                ),
                title: Text(plan['plan_name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text('建立日期: $dateStr  •  ${details.length} 個動作',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanEditorScreen(
                              targetUserId: widget.traineeId,
                              templatePlan: WorkoutPlan.fromJson(plan),
                              isEditMode: true,
                            ),
                          ),
                        ).then((saved) {
                          if (saved == true && mounted) {
                            setState(() { _plansFuture = _fetchScheduledPlans(); });
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade400),
                      ),
                    ),
                  ],
                ),
                iconColor: Colors.blue.shade700,
                collapsedIconColor: Colors.grey.shade400,
                children: details.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Text('此課表尚無動作', style: TextStyle(color: Colors.grey.shade400)),
                        )
                      ]
                    : details.map((ex) {
                        final name = ex['exercise'] ?? '未知動作';
                        final sets = ex['target_sets'] ?? '-';
                        final reps = ex['target_reps'] ?? '-';
                        final weight = ex['target_weight'];
                        final weightStr = weight != null && (weight as num) > 0 ? '  ${weight}kg' : '';
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey.shade100)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${(ex['order_index'] as int? ?? 0) + 1}',
                                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$sets 組 × $reps 次$weightStr',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                    // 完整組別設定 (prescribed_sets)
                                    if ((ex['prescribed_sets'] as List?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          const Icon(Icons.format_list_numbered, color: Colors.indigo, size: 14),
                                          ...(ex['prescribed_sets'] as List).asMap().entries.map((e) {
                                            final ps = e.value as Map;
                                            final w = ps['weight'] ?? 0;
                                            final r = ps['reps'] ?? 0;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.indigo.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.indigo.shade200),
                                              ),
                                              child: Text(
                                                '組 ${e.key + 1}: ${w}kg × $r',
                                                style: TextStyle(fontSize: 11, color: Colors.indigo.shade800),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            );
          },
        );
      },
    ),
    );
  }

  // === 3. 課表內容 (歷史紀錄) Tab ===
  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _historyFuture = _fetchHistorySessions(); });
        await _historyFuture;
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
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
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                    color: Colors.green.shade50, // 改成與主題一致的綠色系
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                ),
                title: Text(session['plan_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Text('${session['date']} • ${session['exercise_count']} 個動作',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      if (session['total_rate'] != null) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (ctx) {
                          final rate = (session['total_rate'] as num).toDouble();
                          final color = rate >= 80 ? Colors.green.shade700
                              : rate >= 50 ? Colors.orange.shade700
                              : Colors.red.shade400;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${rate.toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
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
    ),
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
