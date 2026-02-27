import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';import 'dart:async';
import 'package:flutter_application_1/models/skin.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 安全地讀取環境變數
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('⚠️ Warning: SUPABASE_URL or SUPABASE_ANON_KEY is missing.');
  }

  // 只有在變數存在時才嘗試初始化
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  runApp(const FitnessRPGApp());
}

class FitnessRPGApp extends StatelessWidget {
  const FitnessRPGApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF00FF41), // 傳說級黑客綠
        scaffoldBackgroundColor: Colors.black,
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Cubic11',
          bodyColor: Colors.white,
          displayColor: const Color(0xFF00FF41),
        ),
      ),
      builder: (context, child) {
        return Container(
          color: Colors.black, // Dark background for the unused space
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: child,
          ),
        );
      },
      home: const WorkoutManager(),
    );
  }
}

class WorkoutManager extends StatefulWidget {
  const WorkoutManager({super.key});
  @override
  State<WorkoutManager> createState() => _WorkoutManagerState();
}

class _WorkoutManagerState extends State<WorkoutManager> {
  final supabase = Supabase.instance.client;
  TextEditingController nameController = TextEditingController();
  TextEditingController coachNameController = TextEditingController();
  String currentUserId = "";
  String currentUserName = "";

  // 1. RPG 基礎狀態
  double totalVolume = 0;
  String currentGender = "不提供";
  double currentHeight = 0;
  double currentWeight = 0;
  double currentBodyFat = 0;
  List<Map<String, dynamic>> weightHistory = [];
  List<Map<String, dynamic>> bodyFatHistory = [];
  int currentRpe = 8;
  List<Map<String, dynamic>> allPlans = [];
  String selectedPlanName = "";
  String selectedPlanId = "";
  bool isTraining = false;
  String? currentSessionId;

  // 2. 副本內部的「任務清單」狀態
  List<dynamic> allExercisesInPlan = [];
  Map<int, bool> exerciseCompletion = {};
  Map<dynamic, dynamic>? activeExercise;
  int? activeExerciseIndex;
  Map<int, String> exerciseFinalRates = {};
  List<Map<String, dynamic>> currentSets = [];

  // 3. 結算與計時相關
  TextEditingController noteController = TextEditingController();
  String lastCompletionRate = "0%";
  List<Map<String, dynamic>> pendingWorkoutLogs = [];


  // 4. 歷史與成就相關
  List<Map<String, dynamic>> historicalSessions = [];
  Map<String, List<Map<String, dynamic>>> achievementStats = {};
  String? selectedAchievementExercise;

  @override
  void initState() {
    super.initState();
  }

  // --- 邏輯區 ---

  // 1. 登入並抓取計畫 (需教練與學員名稱相符)
  Future<void> _loginAndFetchPlans() async {
    final traineeName = currentUserName.trim();
    final coachName = coachNameController.text.trim();
    
    if (traineeName.isEmpty || coachName.isEmpty) {
      _showLoginError("請輸入冒險者與教練名稱！");
      return;
    }

    try {
      // 1. 先找教練
      final coachResponse = await supabase
          .from('users')
          .select('id')
          .ilike('name', coachName)
          .eq('role', 'coach')
          .limit(1);

      if (coachResponse.isEmpty) {
        _showLoginError("找不到名為 '$coachName' 的教練！");
        return;
      }
      
      final coachId = coachResponse[0]['id'];

      // 2. 找該教練旗下的這名學員
      final traineeResponse = await supabase
          .from('users')
          .select('id, name, gender, height, weight, body_fat')
          .ilike('name', traineeName)
          .eq('role', 'trainee')
          .eq('coach_id', coachId)
          .limit(1);

      if (traineeResponse.isEmpty) {
        _showLoginError("教練 '$coachName' 旗下找不到冒險者 '$traineeName'！請請教練為您建立帳號。");
        return;
      }

      // 登入成功
      setState(() {
        currentUserId = traineeResponse[0]['id'];
        currentGender = traineeResponse[0]['gender'] ?? "不提供";
        currentHeight = (traineeResponse[0]['height'] as num?)?.toDouble() ?? 0;
        currentWeight = (traineeResponse[0]['weight'] as num?)?.toDouble() ?? 0;
        currentBodyFat = (traineeResponse[0]['body_fat'] as num?)?.toDouble() ?? 0;
      });
      print("✅ 成功登入：$traineeName (ID: $currentUserId)");

      // 拿到 currentUserId 後繼續抓取計畫
      await _fetchPlans();

    } catch (e) {
      print("❌ 登入發生錯誤: $e");
      _showLoginError("連線錯誤，請稍後再試。");
    }
  }

  void _showLoginError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontFamily: 'Cubic11')), 
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 抓取所有計畫
  Future<void> _fetchPlans() async {
    if (currentUserId.isEmpty) return;

    // 1. 抓取未來課表 (尚未完成的計畫，這邊先簡單列出所有)
    final response = await supabase
        .from('workout_plans')
        .select('id, plan_name')
        .eq('user_id', currentUserId)
        .eq('is_completed', false)
        .order('created_at', ascending: false);
        
    // 2. 抓取歷史課表 (已完成的紀錄)
    final logsResponse = await supabase
        .from('workout_logs')
        .select('id, plan_name, created_at, exercise_name, volume, weight, reps, sets, session_id, set_details, notes')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);
        
    final metricsResponse = await supabase
        .from('user_metrics_history')
        .select('weight, body_fat, created_at')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: true);
        
    final metricsList = List<Map<String, dynamic>>.from(metricsResponse);
    final logs = List<Map<String, dynamic>>.from(logsResponse);
    
    // 1. 先把所有 log 照梯次分組
    final Map<String, List<Map<String, dynamic>>> groupedLogs = {};
    for (var log in logs) {
      final sessionId = log['session_id'];
      final dateStr = (log['created_at'] as String).substring(0, 10);
      final planName = log['plan_name'] ?? '未知課表';
      // 這裡改以 session_id 為主，舊資料保留 date_planName 作為 group key
      final key = sessionId != null ? sessionId.toString() : '${dateStr}_$planName';
      
      if (!groupedLogs.containsKey(key)) groupedLogs[key] = [];
      groupedLogs[key]!.add(log);
    }
    
    // 將歷史紀錄分組 (依據 session_id，若無則降級使用 date_planKey)
    final Map<String, Map<String, dynamic>> sessionsMap = {};
    final Map<String, List<Map<String, dynamic>>> statsMap = {};
    
    // 2. 只把「有包含結算」的群組抽出來當作有效歷史
    for (var entry in groupedLogs.entries) {
      final key = entry.key; // 這裡改以 session_id 為主，舊資料保留 date_planName
      final sessionLogs = entry.value;
      
      bool isCompleted = sessionLogs.any((log) => (log['exercise_name'] ?? '').contains('🏆 副本總結'));
      if (isCompleted) {
        final summaryLog = sessionLogs.firstWhere((log) => (log['exercise_name'] ?? '').contains('🏆 副本總結'));
        final sessionNote = summaryLog['notes'] ?? '';
        final planName = summaryLog['plan_name'] ?? '未知課表';
        final dateStr = (summaryLog['created_at'] as String).substring(0, 10);
        
        sessionsMap[key] = {
          'date': dateStr,
          'plan_name': planName,
          'notes': sessionNote,
          'logs': <Map<String, dynamic>>[],
        };
        
        for (var log in sessionLogs) {
          final exName = log['exercise_name'] ?? '未知名稱';
          final weight = (log['weight'] as num?)?.toDouble() ?? 0.0;
          final volume = (log['volume'] as num?)?.toDouble() ?? 0.0;
          final reps = (log['reps'] as num?)?.toInt() ?? 0;
          
          if (!exName.contains('🏆 副本總結')) {
            // 保存每項動作到當天課表的歷程中以便展開檢視
            sessionsMap[key]!['logs'].add({
              'exercise_name': exName,
              'weight': weight,
              'reps': reps,
              'sets': log['sets'] ?? 0,
              'volume': volume,
              'set_details': log['set_details'], // 新增的詳細資料
            });
            
            // 加入成就圖表的數據
            if (!statsMap.containsKey(exName)) {
              statsMap[exName] = [];
            }
            statsMap[exName]!.add(log);
          }
        }
      }
    }
    
    // 計算 Total Volume
    double calculatedTotalVolume = 0;
    for (var log in logs) {
      if ((log['exercise_name'] ?? '').contains('🏆 副本總結')) continue;
      final setDetails = log['set_details'] as List<dynamic>?;
      if (setDetails != null && setDetails.isNotEmpty) {
         for (var set in setDetails) {
            double w = (set['weight'] as num?)?.toDouble() ?? 0;
            int r = (set['reps'] as num?)?.toInt() ?? 0;
            calculatedTotalVolume += (w > 0) ? (w * r) : (r * 10);
         }
      } else {
         double w = (log['weight'] as num?)?.toDouble() ?? 0;
         int r = (log['reps'] as num?)?.toInt() ?? 0;
         int s = (log['sets'] as num?)?.toInt() ?? 0;
         calculatedTotalVolume += ((w > 0) ? (w * r) : (r * 10)) * s;
      }
    }

    // 排序成就資料 (由舊到新)
    for (var key in statsMap.keys) {
       statsMap[key]!.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    }
    
    final sessionsList = sessionsMap.values.toList();
    sessionsList.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    setState(() {
      totalVolume = calculatedTotalVolume;
      weightHistory = metricsList.where((m) => m['weight'] != null).toList();
      bodyFatHistory = metricsList.where((m) => m['body_fat'] != null).toList();
      allPlans = List<Map<String, dynamic>>.from(response);
      historicalSessions = sessionsList;
      achievementStats = statsMap;
      if (statsMap.isNotEmpty && selectedAchievementExercise == null) {
         selectedAchievementExercise = statsMap.keys.first;
      }
    });
  }

  // 初始化副本佈告欄
  Future<void> _startWorkout(Map<String, dynamic> plan) async {
    final response = await supabase
        .from('plan_details')
        .select('*, rest_time_seconds')
        .eq('plan_id', plan['id'])
        .order('order_index', ascending: true);
    setState(() {
      selectedPlanName = plan['plan_name'] ?? '未命名課表';
      selectedPlanId = plan['id'];
      allExercisesInPlan = response;
      exerciseCompletion = {
        for (int i = 0; i < response.length; i++) i: false,
      };
      isTraining = true;
      currentSessionId = const Uuid().v4(); // 初始化新的 session ID
      activeExercise = null;
      activeExerciseIndex = null;
      pendingWorkoutLogs.clear();
    });
  }

  // 點擊任務進入特定動作
  void _enterExercise(dynamic ex, int index) {
    setState(() {
      activeExercise = ex;
      activeExerciseIndex = index;
      currentRpe = 8;

      int numSets = ex['_current_target_sets'] ?? ex['target_sets'] ?? 3;
      double targetWeight = (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
      int targetReps = ex['_current_target_reps'] ?? ex['target_reps'] ?? 0;

      currentSets = List.generate(
        numSets,
        (i) => {
          "set_num": i + 1,
          "weight": targetWeight,
          "reps": targetReps,
          "rate": "0%",
        },
      );
    });
  }



  // 啟動休息與達成率計算
  void _startRest(int setIdx) {
    final ex = activeExercise!;
    double targetWeight = (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
    int targetReps = ex['_current_target_reps'] ?? ex['target_reps'] ?? 0;
    
    double rateValue = 0.0;
    if (targetWeight > 0) {
      double targetVol = targetWeight * targetReps;
      double actualVol = currentSets[setIdx]['weight'] * currentSets[setIdx]['reps'];
      rateValue = targetVol > 0 ? (actualVol / targetVol) : 1.0;
    } else {
      rateValue = targetReps > 0 ? (currentSets[setIdx]['reps'] / targetReps) : 1.0;
    }
    int rate = (rateValue * 100).toInt();

    setState(() {
      currentSets[setIdx]['rate'] = "$rate%";
      lastCompletionRate = "$rate%";
    });

    int restTimeSeconds = ex['rest_time_seconds'] ?? 60; // 優先使用資料庫設定的秒數，預設 60 秒

    showDialog(
      context: context,
      barrierDismissible: false, // 禁止點擊背景關閉
      builder: (BuildContext context) {
        return RestTimerDialog(restTimeSeconds: restTimeSeconds);
      },
    );
  }

  // 單一任務完成 (打勾回清單)
  Future<void> _completeActiveExercise() async {
    if (activeExercise == null || activeExerciseIndex == null) return;

    double totalRateSum = 0;
    for (var s in currentSets) {
      double targetWeight = (activeExercise!['_current_target_weight'] ?? activeExercise!['target_weight'] ?? 0).toDouble();
      int targetReps = (activeExercise!['_current_target_reps'] ?? activeExercise!['target_reps'] ?? 0);
      
      double rateValue = 0.0;
      if (targetWeight > 0) {
        double targetVol = targetWeight * targetReps;
        double actualVol = (s['weight'] * s['reps']).toDouble();
        rateValue = targetVol > 0 ? (actualVol / targetVol) : 1.0;
      } else {
        rateValue = targetReps > 0 ? (s['reps'] / targetReps) : 1.0;
      }
      totalRateSum += rateValue;
    }

    double avgRate = (totalRateSum / currentSets.length) * 100;
    String rate = "${avgRate.toStringAsFixed(0)}%";

    double exerciseVolume = 0;
    for (var s in currentSets) {
      double w = (s['weight'] as num?)?.toDouble() ?? 0;
      int r = (s['reps'] as num?)?.toInt() ?? 0;
      exerciseVolume += (w > 0) ? (w * r) : (r * 10);
    }

    // 2. 準備完整的 logData
    final logData = {
      "user_id": currentUserId,
      "plan_name": selectedPlanName,
      "exercise_name": activeExercise!['_current_exercise_name'] ?? activeExercise!['exercise'],
      "weight": (currentSets.last['weight'] as num).toDouble(),
      "reps": (currentSets.last['reps'] as num).toInt(),
      "sets": currentSets.length,
      "set_details": currentSets, // 寫入詳細 JSON 結構
      "session_id": currentSessionId, // 寫入 session_id
      "completion_rate": rate,
      "volume": exerciseVolume,
      "rpe": currentRpe,
      "created_at": DateTime.now().toIso8601String(),
    };

    // 加入本地暫存，等結算一起送出
    pendingWorkoutLogs.add(logData);
    print("✅ 紀錄已暫存：$rate, 總容量: ${logData['volume']}, RPE: $currentRpe");

    setState(() {
      exerciseFinalRates[activeExerciseIndex!] = rate;
      exerciseCompletion[activeExerciseIndex!] = true;
      for (var s in currentSets) {
        double w = (s['weight'] as num).toDouble();
        int r = (s['reps'] as num).toInt();
        totalVolume += (w > 0) ? (w * r) : (r * 10);
      }
      activeExercise = null;
      activeExerciseIndex = null;
    });
  }

  // --- UI 區 ---

  @override
  Widget build(BuildContext context) {
    double totalSessionRate = 0;
    if (exerciseFinalRates.isNotEmpty) {
      double sum = 0;
      for (var rateString in exerciseFinalRates.values) {
        sum += double.tryParse(rateString.replaceAll('%', '')) ?? 0;
      }
      totalSessionRate = sum / exerciseFinalRates.length;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (currentUserId.isEmpty)
              Expanded(child: _buildLoginForm())
            else ...[
              _buildCharHeader(),
              Expanded(
                child: !isTraining
                    ? _buildLobbyMode()
                    : (activeExercise == null
                          ? _buildQuestLog(totalSessionRate) 
                          : _buildBattleMode()),
              ),
            ]
          ],
        ),
      ),
    );
  }


  // 顯示個人資料設定對話框
  void _showProfileDialog() {
    TextEditingController heightCtrl = TextEditingController(text: currentHeight > 0 ? currentHeight.toString() : '');
    TextEditingController weightCtrl = TextEditingController(text: currentWeight > 0 ? currentWeight.toString() : '');
    TextEditingController bodyFatCtrl = TextEditingController(text: currentBodyFat > 0 ? currentBodyFat.toString() : '');
    String selectedGender = ["男", "女", "不提供"].contains(currentGender) ? currentGender : "不提供";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("冒險者身體密碼", style: TextStyle(fontFamily: 'Cubic11', color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: "性別", labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Cubic11')),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cubic11'),
                      items: ["男", "女", "不提供"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) {
                        setStateDialog(() => selectedGender = val!);
                      },
                    ),
                    TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cubic11'),
                      decoration: const InputDecoration(labelText: "身高 (cm)", labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Cubic11')),
                    ),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cubic11'),
                      decoration: const InputDecoration(labelText: "體重 (kg)", labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Cubic11')),
                    ),
                    TextField(
                      controller: bodyFatCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cubic11'),
                      decoration: const InputDecoration(labelText: "體脂肪 (%)", labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Cubic11')),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("取消", style: TextStyle(color: Colors.grey, fontFamily: 'Cubic11')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    double newHeight = double.tryParse(heightCtrl.text) ?? 0;
                    double newWeight = double.tryParse(weightCtrl.text) ?? 0;
                    double newBodyFat = double.tryParse(bodyFatCtrl.text) ?? 0;
                    
                    try {
                      await supabase.from('users').update({
                        'gender': selectedGender,
                        'height': newHeight,
                        'weight': newWeight,
                        'body_fat': newBodyFat,
                      }).eq('id', currentUserId);

                      bool metricsChanged = (newWeight != currentWeight || newBodyFat != currentBodyFat);

                      if (metricsChanged && newWeight > 0) {
                        await supabase.from('user_metrics_history').insert({
                          'user_id': currentUserId,
                          'weight': newWeight,
                          'body_fat': newBodyFat,
                        });
                      }

                      setState(() {
                         currentGender = selectedGender;
                         currentHeight = newHeight;
                         currentWeight = newWeight;
                         currentBodyFat = newBodyFat;
                      });
                      
                      if (metricsChanged) {
                         _fetchPlans(); // re-fetch metrics history
                      }
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('資料已更新', style: TextStyle(fontFamily: 'Cubic11')), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      print("Error updating profile: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF41)),
                  child: const Text("儲存", style: TextStyle(color: Colors.black, fontFamily: 'Cubic11')),
                ),
              ],
            );
          },
        );
      },
    );
  }




  // 頂部等級條
  Widget _buildCharHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      // 🚀 使用 Row 讓頭像和資訊併排
      child: Row(
        children: [
          // --- 1. 左側：自動偵測頭像區 ---
          ValueListenableBuilder<Skin>(
            valueListenable: currentSkin,
            builder: (context, skin, child) {
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SkinSelectionModal(),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00FF41), width: 3),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      skin.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/novice.png', // 失敗抓預設
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 20), // 間距
          // --- 2. 右側：冒險者資訊 ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "⚔️ 冒險者：$currentUserName",
                      style: TextStyle(fontFamily: 'Cubic11',
                        color: Theme.of(context).primaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.manage_accounts, color: Colors.white54),
                      onPressed: () => _showProfileDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "總訓練量: ${totalVolume.toStringAsFixed(0)} kg",
                        style: const TextStyle(fontFamily: 'Cubic11', color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 大廳選計畫 (改為 Tabbed View)
  Widget _buildLobbyMode() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
             labelColor: const Color(0xFF00FF41),
             unselectedLabelColor: Colors.grey,
             indicatorColor: const Color(0xFF00FF41),
             labelStyle: const TextStyle(fontFamily: 'Cubic11', fontSize: 16),
             tabs: const [
               Tab(text: "未來課表"),
               Tab(text: "歷史紀錄"),
               Tab(text: "成就圖表"),
             ],
          ),
          Expanded(
             child: TabBarView(
                children: [
                   _buildFuturePlansTab(),
                   _buildHistoryTab(),
                   _buildAchievementsTab(),
                ],
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "🔑 冒險者登入",
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: coachNameController,
          decoration: InputDecoration(
            hintText: "教練名稱 (例如：Test Coach)",
            hintStyle: TextStyle(fontFamily: 'Cubic11',color: Colors.grey.shade500),
            border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
            prefixIcon: const Icon(Icons.shield, color: Colors.white54),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: "冒險者名稱 (例如：Test Trainee)",
            hintStyle: TextStyle(fontFamily: 'Cubic11',color: Colors.grey.shade500),
            border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
            prefixIcon: const Icon(Icons.person, color: Colors.white54),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              currentUserName = nameController.text.trim();
              currentUserId = ""; // 重設 ID 等待撈取
              allPlans.clear(); 
            });
            _loginAndFetchPlans(); 
          },
          icon: const Icon(Icons.login),
          label: const Text("連線至伺服器", style: TextStyle(fontFamily: 'Cubic11', fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF41).withOpacity(0.2),
            foregroundColor: const Color(0xFF00FF41),
            side: const BorderSide(color: Color(0xFF00FF41)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildFuturePlansTab() {
     return ListView(
        padding: const EdgeInsets.all(20),
        children: [
           const Text(
            "📜 冒險者公會佈告欄 (未完成)",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (allPlans.isEmpty)
            const Text("目前沒有任何分配的課表", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontFamily: 'Cubic11')),
          ...allPlans.map(
            (plan) => Card(
              color: Colors.white10,
              child: ListTile(
                title: Text(plan['plan_name'] ?? '未命名課表', style: const TextStyle(fontFamily: 'Cubic11',color: Colors.white)),
                trailing: const Icon(Icons.play_arrow, color: Color(0xFF00FF41)),
                onTap: () => _startWorkout(plan),
              ),
            ),
          ),
        ],
     );
  }

  Widget _buildHistoryTab() {
     return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "📖 過去的輝煌戰役",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (historicalSessions.isEmpty)
            const Text("沒有過去的戰役紀錄", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontFamily: 'Cubic11')),
          ...historicalSessions.map(
            (session) {
              final List<Map<String, dynamic>> sessionLogs = session['logs'] ?? [];
              final note = session['notes'] as String? ?? '';
              return Card(
                color: Colors.white10,
                child: ExpansionTile(
                  leading: const Icon(Icons.history_edu, color: Colors.grey),
                  title: Text(session['plan_name'], style: const TextStyle(fontFamily: 'Cubic11',color: Colors.white)),
                  subtitle: Text(session['date'], style: const TextStyle(fontFamily: 'Cubic11', color: Colors.grey, fontSize: 12)),
                  iconColor: Colors.white54,
                  collapsedIconColor: Colors.white54,
                  children: [
                    ...sessionLogs.reversed.map((log) {
                    final exName = log['exercise_name'];
                    final setDetails = log['set_details'] as List<dynamic>?; // 詳細組數資料

                    if (setDetails != null && setDetails.isNotEmpty) {
                       // 顯示新版詳細組數資料
                       return ExpansionTile(
                          title: Text(exName, style: const TextStyle(fontFamily: 'Cubic11', color: Colors.white, fontSize: 16)),
                          iconColor: const Color(0xFF00FF41),
                          collapsedIconColor: Colors.grey,
                          children: setDetails.map((set) {
                             int setNum = set['set_num'] ?? 0;
                             double weight = (set['weight'] as num?)?.toDouble() ?? 0;
                             int reps = (set['reps'] as num?)?.toInt() ?? 0;
                             String rate = set['rate'] ?? '';
                             return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 40),
                                title: Text("第 $setNum 組:   $weight kg   x   $reps 下", style: const TextStyle(fontFamily: 'Cubic11', color: Colors.white70, fontSize: 14)),
                                trailing: Text(rate, style: const TextStyle(fontFamily: 'Cubic11', color: Colors.green, fontSize: 12)),
                             );
                          }).toList(),
                       );
                    } else {
                        // 顯示舊版資料
                        final w = log['weight'];
                        final r = log['reps'];
                        final s = log['sets'];
                        final valueText = w > 0 ? '$w kg x $s 組 x $r 下' : '$s 組 x $r 下';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 40),
                          title: Text(exName, style: const TextStyle(fontFamily: 'Cubic11', color: Colors.white70, fontSize: 14)),
                          trailing: Text(valueText, style: const TextStyle(fontFamily: 'Cubic11', color: Colors.green, fontSize: 12)),
                        );
                    }
                  }).toList(),
                    if (note.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.05),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote, color: Colors.amber, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "紀錄：$note", 
                                style: const TextStyle(fontFamily: 'Cubic11', color: Colors.amber, fontSize: 13)
                              )
                            ),
                          ],
                        ),
                      ),
                  ],
              ),
            );
          },
          ),
        ],
     );
  }

  Widget _buildAchievementsTab() {
     return DefaultTabController(
       length: 2,
       child: Column(
         children: [
           const TabBar(
              labelColor: Color(0xFF00FF41),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF00FF41),
              labelStyle: TextStyle(fontFamily: 'Cubic11', fontSize: 14),
              tabs: [
                 Tab(text: "動作數據"),
                 Tab(text: "身體變化"),
              ]
           ),
           Expanded(
              child: TabBarView(
                 children: [
                    _buildExerciseStatsTab(),
                    _buildBodyStatsTab(),
                 ]
              )
           )
         ]
       )
     );
  }

  Widget _buildExerciseStatsTab() {
     if (achievementStats.isEmpty) {
        return const Center(
           child: Text("尚未累積足夠的成就數據", style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey)),
        );
     }

     final dropdownItems = achievementStats.keys.map((exName) {
         return DropdownMenuItem(
            value: exName,
            child: Text(exName, style: const TextStyle(fontFamily: 'Cubic11', color: Color(0xFF00FF41))),
         );
     }).toList();

     final chartData = achievementStats[selectedAchievementExercise] ?? [];
     List<FlSpot> spots = [];
     double maxVol = 0;
     for (int i = 0; i < chartData.length; i++) {
        double weight = (chartData[i]['weight'] as num?)?.toDouble() ?? 0.0;
        double reps = (chartData[i]['reps'] as num?)?.toDouble() ?? 0.0;
        double yValue = weight > 0 ? weight : reps;
        spots.add(FlSpot(i.toDouble(), yValue));
        if (yValue > maxVol) maxVol = yValue;
     }

     return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
              const Text(
                "📈 戰力成長曲線",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12),
                 decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00FF41)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white10,
                 ),
                 child: DropdownButton<String>(
                    value: selectedAchievementExercise,
                    isExpanded: true,
                    dropdownColor: Colors.black87,
                    underline: const SizedBox(),
                    items: dropdownItems,
                    onChanged: (val) {
                       setState(() {
                          selectedAchievementExercise = val;
                       });
                    },
                 ),
              ),
              const SizedBox(height: 40),
              if (spots.isEmpty)
                 const Center(child: Text("此項目無有效數據", style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey)))
              else
                 Expanded(
                    child: LineChart(
                       LineChartData(
                          gridData: FlGridData(
                             show: true,
                             drawVerticalLine: false,
                             getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                             leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 40,
                                   getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                )
                             ),
                             bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 22,
                                   interval: 1,
                                   getTitlesWidget: (value, meta) {
                                      int idx = value.toInt();
                                      if (idx >= 0 && idx < chartData.length) {
                                         final rawDate = chartData[idx]['created_at'] as String?;
                                         if (rawDate != null && rawDate.length >= 10) {
                                            final dateStr = rawDate.substring(5, 10).replaceFirst('-', '/');
                                            return Padding(
                                               padding: const EdgeInsets.only(top: 5.0),
                                               child: Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 8, fontFamily: 'Cubic11')),
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
                          maxY: maxVol * 1.2,
                          lineBarsData: [
                             LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: const Color(0xFF00FF41),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                   show: true,
                                   color: const Color(0xFF00FF41).withOpacity(0.2),
                                ),
                             ),
                          ],
                       ),
                    ),
                 ),
              const SizedBox(height: 20),
              Text(
                "說明：縱軸為該動作的最高重量 (若無重量則為次數)\\n橫軸為歷史訓練次數 (由左至右為舊到新)",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey.shade500, fontSize: 10),
              ),
           ],
        ),
     );
  }

  // 副本任務佈告欄
  Widget _buildQuestLog(double finalRate) {
    bool allDone = exerciseCompletion.values.every((v) => v == true);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: () => setState(() => isTraining = false), // Go back to lobby
            ),
            Expanded(
              child: Text(
                "🏰 副本：$selectedPlanName",
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cubic11',color: Colors.grey, fontSize: 18),
              ),
            ),
            const SizedBox(width: 48), // 用來平衡左邊的 IconButton，讓標題真正置中
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(allExercisesInPlan.length, (index) {
          final ex = allExercisesInPlan[index];
          bool isDone = exerciseCompletion[index] ?? false;
          
          bool hasAlt = ex['alt_exercise'] != null && ex['alt_exercise'].toString().isNotEmpty;
          bool isUsingAlt = ex['_is_using_alt'] == true; // 本地狀態標記是否已切換為替換動作

          // 決定當前顯示的目標數值
          String displayExName = isUsingAlt ? ex['alt_exercise'] : (ex['exercise'] ?? '動作');
          int displaySets = isUsingAlt ? (ex['alt_target_sets'] ?? ex['target_sets']) : (ex['target_sets'] ?? 0);
          int displayReps = isUsingAlt ? (ex['alt_target_reps'] ?? ex['target_reps']) : (ex['target_reps'] ?? 0);
          num displayWeight = isUsingAlt ? (ex['alt_target_weight'] ?? ex['target_weight']) : (ex['target_weight'] ?? 0);

          return Card(
            color: isDone
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.white10,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? const Color(0xFF00FF41) : Colors.grey,
                  ),
                  title: Text(
                    displayExName,
                    style: TextStyle(fontFamily: 'Cubic11',color: isDone ? Colors.grey : Colors.white),
                  ),
                  subtitle: isDone
                      ? Text(
                          "達成率 : ${exerciseFinalRates[index] ?? '0%'}",
                          style: TextStyle(fontFamily: 'Cubic11',
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        )
                      : Text("$displaySets 組 x $displayReps 下 @ ${displayWeight}kg" + ((ex['target_rpe'] ?? 0) > 0 && (!isUsingAlt) ? " RPE ${ex['target_rpe']}" : ""), style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey, fontSize: 12)),
                  trailing: isDone
                      ? null
                      : const Icon(Icons.play_arrow, color: Color(0xFF00FF41)),
                  onTap: isDone
                      ? null
                      : () {
                          // 將當前決定好的動作名稱塞回 ex 中，以便後續記錄
                          ex['_current_exercise_name'] = displayExName;
                          ex['_current_target_sets'] = displaySets;
                          ex['_current_target_reps'] = displayReps;
                          ex['_current_target_weight'] = displayWeight;
                          _enterExercise(ex, index);
                        },
                ),
                if (!isDone && hasAlt)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0, top: 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.cyanAccent),
                        label: Text(
                          isUsingAlt ? "切換回原動作" : "切換替換動作 (${ex['alt_exercise']})", 
                          style: const TextStyle(fontFamily: 'Cubic11', fontSize: 11, color: Colors.cyanAccent)
                        ),
                        onPressed: () {
                           setState(() {
                              ex['_is_using_alt'] = !isUsingAlt;
                           });
                        },
                        style: TextButton.styleFrom(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                           minimumSize: Size.zero,
                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (allDone && allExercisesInPlan.isNotEmpty) _buildFinalSummary(finalRate),
      ],
    );
  }

  Widget _buildRpeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [2, 4, 6, 8, 10]
          .map(
            (val) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ChoiceChip(
                label: Text("RPE $val", style: TextStyle(fontFamily: 'Cubic11',)),
                selected: currentRpe == val,
                onSelected: (bool selected) {
                  setState(() => currentRpe = val);
                },
              ),
            ),
          )
          .toList(),
    );
  }

  // 戰鬥畫面 (做動作)
  Widget _buildBattleMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () => setState(() => activeExercise = null), // 回到副本清單
              ),
              Expanded(
                child: Text(
                  "🔥 ${activeExercise!['exercise']}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cubic11',color: Theme.of(context).primaryColor, fontSize: 24), // 幫標題字稍微縮小一點避免太擠
                ),
              ),
              const SizedBox(width: 48), // 用來平衡左邊的 IconButton，讓標題真正置中
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "🥵 疲勞度 (RPE)：",
                style: TextStyle(fontFamily: 'Cubic11',color: Colors.white, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.orange,
                ),
                onPressed: () => setState(
                  () => currentRpe = currentRpe > 1 ? currentRpe - 1 : 1,
                ),
              ),
              Text(
                "$currentRpe",
                style: TextStyle(fontFamily: 'Cubic11',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.orange,
                ),
                onPressed: () => setState(
                  () => currentRpe = currentRpe < 10 ? currentRpe + 1 : 10,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: currentSets.length,
            itemBuilder: (context, i) => _buildSetCard(i),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            minimumSize: const Size(double.infinity, 80),
          ),
          onPressed: _completeActiveExercise,
          child: Text(
            "完成動作 (領取經驗值)",
            style: TextStyle(fontFamily: 'Cubic11',
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // 組數調整卡片
  Widget _buildSetCard(int i) {
    return Card(
      margin: const EdgeInsets.all(10),
      color: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "第 ${i + 1} 組",
                  style: TextStyle(fontFamily: 'Cubic11',color: Theme.of(context).primaryColor),
                ),
                if (currentSets[i]['rate'] != "")
                  Text(
                    "達成率: ${currentSets[i]['rate']}",
                    style: TextStyle(fontFamily: 'Cubic11',color: Colors.orange),
                  ),
                IconButton(
                  icon: const Icon(Icons.timer, color: Colors.green),
                  onPressed: () => _startRest(i),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAdjuster(i, "weight", 0.5, "kg"),
                _buildAdjuster(i, "reps", 1, "下"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjuster(int i, String key, double delta, String unit) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => setState(() => currentSets[i][key] -= delta),
        ),
        Text(
          "${currentSets[i][key]}$unit",
          style: TextStyle(fontFamily: 'Cubic11',fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setState(() => currentSets[i][key] += delta),
        ),
      ],
    );
  }

  // 副本結算與備註
  // 🚀 修改這個方法，讓它能接收總分並存檔
  Widget _buildFinalSummary(double finalScore) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF00FF41)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            "🏆 副本清空！總達成率：${finalScore.toStringAsFixed(1)}%",
            style: TextStyle(fontFamily: 'Cubic11',color: const Color(0xFF00FF41), fontSize: 22),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: noteController, // 🚀 這就是你原本就有的那支筆！
            maxLines: null, // 支援多行
            keyboardType: TextInputType.multiline, // 支援多行輸入鍵盤
            decoration: InputDecoration(
              labelText: "寫下冒險心得 (備註)...",
              labelStyle: TextStyle(fontFamily: 'Cubic11',color: Colors.grey),
            ),
            style: TextStyle(fontFamily: 'Cubic11',color: Colors.white),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF41), // 亮綠色
              foregroundColor: Colors.black, // 黑色文字
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              // 🚀 3. 按下結束時，把暫存紀錄與總分、備註一起送上雲端
              try {
                String finalRateString = "${finalScore.toStringAsFixed(0)}%";
                
                // 準備最後的結算紀錄
                final summaryLog = {
                  'user_id': currentUserId,
                  'plan_name': selectedPlanName,
                  'exercise_name': '🏆 副本總結結算', // 🚀 這樣你一眼就能看出哪一行是總結
                  'completion_rate': finalRateString,
                  'total_rate': finalScore,
                  'notes': noteController.text, // 抓取筆記內容
                  'session_id': currentSessionId, // 掛鉤同一個 session
                  'created_at': DateTime.now().toIso8601String(),
                };

                // 合併全部要上傳的資料
                List<Map<String, dynamic>> allLogsToUpload = List.from(pendingWorkoutLogs);
                allLogsToUpload.add(summaryLog);

                // 一次上傳
                await supabase.from('workout_logs').insert(allLogsToUpload);
                print("✅ 結算與動作紀錄存檔成功！");

                // 將該筆課表標示為完成，避免重複執行並保留供教練複製
                if (selectedPlanId.isNotEmpty) {
                  await supabase.from('workout_plans').update({'is_completed': true}).eq('id', selectedPlanId);
                  print("✅ 課表已標示為完成！");
                }
              } catch (e) {
                print("❌ 資料存檔或刪除失敗：$e");
              }

              setState(() {
                isTraining = false;
                noteController.clear(); // 結束後把筆記擦乾淨，下次用
                pendingWorkoutLogs.clear();
              });
              
              // 🚀 存檔後立即重新整理紀錄，讓歷史課表能馬上看到這筆資料！
              await _fetchPlans();
            },
            child: Text(
              "上傳數據並回村莊",
              style: TextStyle(fontFamily: 'Cubic11',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
Widget _buildBodyStatsTab() {
      if (weightHistory.isEmpty && bodyFatHistory.isEmpty) {
         return const Center(
            child: Text("尚未記錄任何身體數據，請點擊上方頭像旁的設定按鈕新增。", style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
         );
      }

      List<FlSpot> weightSpots = [];
      double maxWeight = 0;
      double minWeight = double.infinity;
      for (int i = 0; i < weightHistory.length; i++) {
         double w = (weightHistory[i]['weight'] as num).toDouble();
         weightSpots.add(FlSpot(i.toDouble(), w));
         if (w > maxWeight) maxWeight = w;
         if (w < minWeight) minWeight = w;
      }
      if (minWeight == double.infinity) minWeight = 0;

      List<FlSpot> fatSpots = [];
      double maxFat = 0;
      double minFat = double.infinity;
      for (int i = 0; i < bodyFatHistory.length; i++) {
         double f = (bodyFatHistory[i]['body_fat'] as num).toDouble();
         fatSpots.add(FlSpot(i.toDouble(), f));
         if (f > maxFat) maxFat = f;
         if (f < minFat) minFat = f;
      }
      if (minFat == double.infinity) minFat = 0;

      return Padding(
         padding: const EdgeInsets.all(20),
         child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               const Text(
                 "💪 體重變化與體脂走勢",
                 textAlign: TextAlign.center,
                 style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 20),
               if (weightSpots.isEmpty && fatSpots.isEmpty)
                  const Center(child: Text("目前無記錄", style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey)))
               else
                  Expanded(
                     child: LineChart(
                        LineChartData(
                           gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                           ),
                           titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                 axisNameWidget: const Text("數值", style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Cubic11')),
                                 sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                 )
                              ),
                              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                           ),
                           borderData: FlBorderData(show: false),
                           minX: 0,
                           maxX: maxWeight > 0 || maxFat > 0 ? max(
                             weightSpots.length > fatSpots.length ? weightSpots.length.toDouble() - 1 : fatSpots.length.toDouble() - 1,
                             1.0
                           ) : 1.0,
                           minY: min(minWeight * 0.9, minFat * 0.9),
                           maxY: max(maxWeight * 1.1, maxFat * 1.1),
                           lineBarsData: [
                              if (weightSpots.isNotEmpty)
                                 LineChartBarData(
                                    spots: weightSpots,
                                    isCurved: true,
                                    color: Colors.blueAccent,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                 ),
                              if (fatSpots.isNotEmpty)
                                 LineChartBarData(
                                    spots: fatSpots,
                                    isCurved: true,
                                    color: Colors.redAccent,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                 ),
                           ],
                        ),
                     ),
                  ),
               const SizedBox(height: 20),
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Container(width: 12, height: 12, color: Colors.blueAccent),
                   const SizedBox(width: 8),
                   const Text("體重 (kg)", style: TextStyle(color: Colors.grey, fontFamily: 'Cubic11', fontSize: 12)),
                   const SizedBox(width: 20),
                   Container(width: 12, height: 12, color: Colors.redAccent),
                   const SizedBox(width: 8),
                   const Text("體脂 (%)", style: TextStyle(color: Colors.grey, fontFamily: 'Cubic11', fontSize: 12)),
                 ],
               ),
            ],
         ),
      );
   }
}

class SkinSelectionModal extends StatefulWidget {
  const SkinSelectionModal({super.key});

  @override
  State<SkinSelectionModal> createState() => _SkinSelectionModalState();
}

class _SkinSelectionModalState extends State<SkinSelectionModal> {
  // Use ValueNotifier from skin.dart to get current skin
  late Skin selectedPreviewSkin;

  @override
  void initState() {
    super.initState();
    selectedPreviewSkin = currentSkin.value;
  }

  void _showConfirmationDialog(Skin skin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "更換造型確認",
          style: TextStyle(fontFamily: 'Cubic11', color: Colors.white),
        ),
        content: Text(
          "確定要更換造型為 ${skin.name} 嗎？",
          style: const TextStyle(fontFamily: 'Cubic11', color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD72B2B), // Brave Red
            ),
            child: const Text("取消", style: TextStyle(fontFamily: 'Cubic11')),
          ),
          TextButton(
            onPressed: () {
              // Sync state
              currentSkin.value = skin;
              Navigator.pop(context); // Close dialog
              // Modal stays open as requested
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2975C6), // Knight Blue
            ),
            child: const Text("確定", style: TextStyle(fontFamily: 'Cubic11')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero, // Full screen modal
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            // Preview Area
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF2975C6), // Knight Blue
                            width: 8, // Thick 8-bit style border
                          ),
                        ),
                        child: Image.asset(
                          selectedPreviewSkin.imagePath,
                          fit: BoxFit.contain,
                           errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/novice.png', 
                                fit: BoxFit.contain,
                              );
                            },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _showConfirmationDialog(selectedPreviewSkin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2975C6), // Knight Blue
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      "更換為大頭像",
                      style: TextStyle(fontFamily: 'Cubic11', fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "選擇造型",
              style: TextStyle(fontFamily: 'Cubic11', color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 10),

            // Selection Area (Grid)
            Expanded(
              flex: 3,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8, // Fixed ratio to prevent stretching
                ),
                itemCount: allSkins.length,
                itemBuilder: (context, index) {
                  final skin = allSkins[index];
                  final isSelected = skin.id == selectedPreviewSkin.id; // Correct comparsion

                  return GestureDetector(
                    onTap: () {
                       setState(() {
                         selectedPreviewSkin = skin;
                       });
                       // _showConfirmationDialog(skin); // Removed auto-trigger
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected 
                            ? Border.all(color: const Color(0xFF2975C6), width: 4)
                            : Border.all(color: Colors.grey, width: 1),
                        color: Colors.white10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                skin.imagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image_not_supported, color: Colors.white);
                                },
                              ),
                            ),
                          ),
                          Text(
                            skin.name,
                            style: const TextStyle(
                              fontFamily: 'Cubic11', 
                              color: Colors.white, 
                              fontSize: 12
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestTimerDialog extends StatefulWidget {
  final int restTimeSeconds;

  const RestTimerDialog({super.key, required this.restTimeSeconds});

  @override
  State<RestTimerDialog> createState() => _RestTimerDialogState();
}

class _RestTimerDialogState extends State<RestTimerDialog> {
  late DateTime endTime;
  late Timer timer;
  int remainingSeconds = 0;
  bool isFinished = false;

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.restTimeSeconds;
    endTime = DateTime.now().add(Duration(seconds: remainingSeconds));

    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      final now = DateTime.now();
      if (now.isAfter(endTime)) {
        setState(() {
          remainingSeconds = 0;
          isFinished = true;
        });
        t.cancel();
        _triggerVibration();
      } else {
        setState(() {
          remainingSeconds = endTime.difference(now).inSeconds;
        });
      }
    });
  }

  Future<void> _triggerVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator ?? false) {
      bool? hasCustom = await Vibration.hasCustomVibrationsSupport();
      if (hasCustom ?? false) {
        Vibration.vibrate(duration: 1000);
      } else {
        // Fallback for iOS (standard vibration or multiple short vibrations)
        Vibration.vibrate();
        await Future.delayed(const Duration(milliseconds: 400));
        Vibration.vibrate();
        await Future.delayed(const Duration(milliseconds: 400));
        Vibration.vibrate();
      }
    } else {
      // Final fallback using system HapticFeedback
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 400));
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "休息時間",
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Cubic11', color: Colors.white, fontSize: 24),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFinished ? "時間到！" : "💖 體力回復中...",
            style: TextStyle(
              fontFamily: 'Cubic11',
              color: isFinished ? const Color(0xFF00FF41) : Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "$remainingSeconds s",
            style: TextStyle(
              fontFamily: 'Cubic11',
              color: isFinished ? const Color(0xFF00FF41) : Colors.orange,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF41),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Text(
            "停止休息，進行下一個",
            style: TextStyle(fontFamily: 'Cubic11', fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
