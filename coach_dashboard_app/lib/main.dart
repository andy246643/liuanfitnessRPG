import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'screens/create_plan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 安全地讀取環境變數
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('⚠️ Warning: SUPABASE_URL or SUPABASE_ANON_KEY is missing.');
  }

  // 只有在變數存在時才嘗試初始化，避免 crash
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  runApp(const CoachDashboardApp());
}

class CoachDashboardApp extends StatelessWidget {
  const CoachDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coach Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CoachLoginScreen(),
    );
  }
}

// ----------------------------------------------------------------------
// 1. 教練登入畫面
// ----------------------------------------------------------------------
class CoachLoginScreen extends StatefulWidget {
  const CoachLoginScreen({super.key});

  @override
  State<CoachLoginScreen> createState() => _CoachLoginScreenState();
}

class _CoachLoginScreenState extends State<CoachLoginScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Test Coach");
  bool _isLoading = false;
  String _errorMessage = "";

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('*')
          .ilike('name', name)
          .eq('role', 'coach')
          .limit(1);

      if (response.isNotEmpty) {
        final coachId = response[0]['id'];
        final coachName = response[0]['name'];
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TraineeListScreen(
              coachId: coachId,
              coachName: coachName,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = "找不到名為 '$name' 的教練帳號，請確認名稱是否正確。";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "登入發生錯誤: $e";
      });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
  }

  Future<void> _registerCoach() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = "請先輸入想要註冊的教練名稱");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final supabase = Supabase.instance.client;
      // 1. 檢查是否已經有同名的教練了
      final checkResponse = await supabase
          .from('users')
          .select('id')
          .ilike('name', name)
          .eq('role', 'coach')
          .limit(1);

      if (checkResponse.isNotEmpty) {
        setState(() {
          _errorMessage = "名稱已被使用！請更換一個名稱重新註冊。";
        });
        return;
      }

      // 2. 建立新的教練帳號
      // Supabase 的 UUID 會透過資料庫的 DEFAULT gen_random_uuid 自動生成
      // (如果沒有設 DEFAULT，也可以在這裡手動用 uuid 套件產生，但我們讓 DB 自己配發)
      final insertResponse = await supabase.from('users').insert({
        'name': name,
        'role': 'coach'
      }).select(); // 取得剛建立好的資料(含產生的 ID)

      if (insertResponse.isNotEmpty) {
        final newCoachId = insertResponse[0]['id'];
        final newCoachName = insertResponse[0]['name'];

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 成功註冊教練：$newCoachName', style: const TextStyle(fontFamily: 'Cubic11'))),
        );

        // 3. 自動登入並跳轉
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TraineeListScreen(
              coachId: newCoachId,
              coachName: newCoachName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "註冊發生錯誤: $e\n(可能是因為您的資料庫 users.id 欄位不允許為空且沒有設定自動生成 UUID)";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.fitness_center, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                '教練管理系統',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '教練名稱',
                  hintText: '例如: Test Coach',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('登 入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading ? null : _registerCoach,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.blue),
                  foregroundColor: Colors.blue,
                ),
                child: _isLoading
                    ? const SizedBox.shrink()
                    : const Text('🌟 註冊新教練', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. 學員列表首頁 (My Trainees)
// ----------------------------------------------------------------------
class TraineeListScreen extends StatefulWidget {
  final String coachId;
  final String coachName;

  const TraineeListScreen({
    super.key,
    required this.coachId,
    required this.coachName,
  });

  @override
  State<TraineeListScreen> createState() => _TraineeListScreenState();
}

class _TraineeListScreenState extends State<TraineeListScreen> {
  Future<List<dynamic>> _fetchTrainees() async {
    try {
      final supabase = Supabase.instance.client;
      // 取得特定教練指導的身分為 trainee 的使用者
      final response = await supabase
          .from('users')
          .select('id, name, created_at')
          .eq('role', 'trainee')
          .eq('coach_id', widget.coachId)
          .order('created_at', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      throw Exception('Fetch trainees failed: $e');
    }
  }

  Future<void> _createNewTrainee(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增學員', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('輸入學員名稱來建立新帳號並指派給自己。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '學員名稱',
                      hintText: '例如: 小明',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setDialogState(() => isCreating = true);

                          try {
                            final supabase = Supabase.instance.client;
                            // Generate simple UUID
                            final newUuid = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padRight(32, '0').replaceAllMapped(RegExp(r'(.{8})(.{4})(.{4})(.{4})(.{12})'), (m) => '${m[1]}-${m[2]}-${m[3]}-${m[4]}-${m[5]}');
                            
                            await supabase.from('users').insert({
                              'id': newUuid,
                              'name': name,
                              'role': 'trainee',
                              'coach_id': widget.coachId,
                            });
                            
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            setState(() {}); // 重新載入列表
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('成功新增學員: $name')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('新增失敗: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                            );
                            setDialogState(() => isCreating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: isCreating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('確認新增'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.coachName} 的指導學員', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '新增學員',
            onPressed: () => _createNewTrainee(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '登出',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CoachLoginScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchTrainees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('載入學員列表失敗: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('目前還沒有任何學員。', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final trainees = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trainees.length,
            itemBuilder: (context, index) {
              final trainee = trainees[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                    child: Text(trainee['name'].toString().substring(0, 1).toUpperCase()),
                  ),
                  title: Text(trainee['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('ID: ${trainee['id']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TraineeSessionsScreen(
                          traineeId: trainee['id'],
                          traineeName: trainee['name'],
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
      print('Fetch stats error: $e');
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
          .order('created_at', ascending: true);

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
      print('Fetch exercise stats err: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchExerciseStats(); // 頁面載入時先抓圖表數據
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
  // === 1. 學員資訊 Tab ===
  Widget _buildInfoTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchRecentTrainingStats(),
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

    final dropdownItems = achievementStats.keys.map((exName) {
      return DropdownMenuItem(
        value: exName,
        child: Text(exName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      );
    }).toList();

    final chartData = achievementStats[selectedAchievementExercise!] ?? [];
    List<FlSpot> spots = [];
    double maxVol = 0;
    
    for (int i = 0; i < chartData.length; i++) {
      double weight = (chartData[i]['weight'] as num?)?.toDouble() ?? 0.0;
      double reps = (chartData[i]['reps'] as num?)?.toDouble() ?? 0.0;
      double yValue = weight > 0 ? weight : reps; // 優先取重量，否則取次數
      spots.add(FlSpot(i.toDouble(), yValue));
      if (yValue > maxVol) maxVol = yValue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedAchievementExercise,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
              items: dropdownItems,
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedAchievementExercise = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (spots.isEmpty)
          const Center(child: Text("此項目無有效數據", style: TextStyle(color: Colors.grey)))
        else
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    )
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: max(1, (spots.length / 5).floor().toDouble()), // 控制標籤數量避免擁擠
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < chartData.length) {
                          final rawDate = chartData[idx]['created_at'] as String?;
                          if (rawDate != null && rawDate.length >= 10) {
                            final dateStr = rawDate.substring(5, 10).replaceFirst('-', '/'); // "MM/DD"
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    )
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: max(spots.length.toDouble() - 1, 1),
                minY: 0,
                maxY: maxVol * 1.2, // 頂部留點空間
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF10B981), // Emerald Green
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
         const SizedBox(height: 16),
         Text(
           "Y-axis shows Volume/Weight/Reps metric over time.",
           textAlign: TextAlign.center,
           style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
         ),
      ],
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
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                  child: const Text('查看', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E5EFF))),
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
                        if (log['set_details'] != null && (log['set_details'] as List).isNotEmpty) ...[
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               _InfoChip(icon: Icons.monitor_heart, label: 'RPE: $rpe', color: Colors.orange),
                               _InfoChip(icon: Icons.data_exploration, label: '總容量: $volume', color: Colors.purple),
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
                                   _InfoChip(icon: Icons.fitness_center, label: '第 $setNum 組:   $weight kg   x   $reps 下', color: Colors.grey.shade700),
                                   _InfoChip(icon: Icons.check_circle, label: rate, color: Colors.green),
                                 ],
                               ),
                             );
                          }),
                        ] else ...[
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
                        ]
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
