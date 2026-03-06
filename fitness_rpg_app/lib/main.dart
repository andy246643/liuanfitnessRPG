import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter_application_1/models/skin.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 設置系統狀態列樣式（避免手機出現奇怪顏色橫幅）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 安全地讀取環境變數
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('⚠️ Warning: SUPABASE_URL or SUPABASE_ANON_KEY is missing.');
  }

  // 只有在變數存在時才嘗試初始化
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  // 設定全域音訊上下文，預設允許與其他 App 音樂混合
  AudioPlayer.global.setAudioContext(AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient, // ambient 不會中斷其他音樂
    ),
    android: AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  ));

  runApp(const FitnessRPGApp());
}

// --- 全域主題狀態 ---
final ValueNotifier<bool> isRpgMode = ValueNotifier(false);

// 1. 定義品牌色彩常數 (Zen Style)
class ZenColors {
  static const Color sageGreen = Color(0xFF8DAA91);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Color(0xFF94A3B8);
}

Color get txtCol => isRpgMode.value ? Color(0xFF4AF626) : ZenColors.textDark;
Color get dimCol =>
    isRpgMode.value ? const Color(0xFF4AF626).withOpacity(0.5) : ZenColors.textLight;
Color get bgCol => isRpgMode.value ? Colors.black : ZenColors.background;
Color get cardBgCol => isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white;
Color get pCol => isRpgMode.value ? Color(0xFF4AF626) : ZenColors.sageGreen;
String? get fFam => isRpgMode.value ? 'Cubic11' : null;

// 2. 建立具備品牌質感的卡片組件
class ZenCard extends StatelessWidget {
  final Widget child;
  final double padding;
  final Color? color;
  final VoidCallback? onTap;

  const ZenCard({super.key, required this.child, this.padding = 20, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color ?? (isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(isRpgMode.value ? 4 : 32),
        border: isRpgMode.value 
            ? Border.all(color: pCol, width: 2)
            : null,
        boxShadow: isRpgMode.value 
          ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 4))]
          : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
      );
    }
    return card;
  }
}

// 預設為長壽模式

ThemeData _buildLongevityTheme() {
  return ThemeData.light().copyWith(
    primaryColor: ZenColors.sageGreen,
    scaffoldBackgroundColor: ZenColors.background,
    cardColor: Colors.white,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: ZenColors.textDark,
      displayColor: ZenColors.sageGreen,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZenColors.background,
      foregroundColor: ZenColors.sageGreen,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
  );
}

ThemeData _buildRpgTheme() {
  return ThemeData.dark().copyWith(
    primaryColor: pCol, // 傳說級黑客綠
    scaffoldBackgroundColor: bgCol,
    cardColor:  const Color(0xFF1A1A1A),
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Cubic11',
      bodyColor: txtCol,
      displayColor: pCol,
    ),
  );
}

class FitnessRPGApp extends StatelessWidget {
   const FitnessRPGApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isRpgMode,
      builder: (context, isRpg, child) {
        return MaterialApp(
          theme: isRpg ? _buildRpgTheme() : _buildLongevityTheme(),
          builder: (context, child) {
            return Container(
              color: isRpg ? bgCol :  const Color(0xFFE0E0E0), // 背景色變換
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints:  BoxConstraints(maxWidth: 450),
                child: child,
              ),
            );
          },
          home:  WorkoutManager(),
        );
      },
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
  TextEditingController currentExerciseNoteController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  String lastCompletionRate = "0%";
  List<Map<String, dynamic>> pendingWorkoutLogs = [];

  // 4. 歷史與成就相關
  List<Map<String, dynamic>> historicalSessions = [];
  Map<String, List<Map<String, dynamic>>> achievementStats = {};
  String? selectedAchievementExercise;
  int currentDashboardIndex = 0; // 0: Dashboard, 1: Plans, 2: History, 3: Stats

  @override
  void initState() {
    super.initState();
  }

  // --- 邏輯區 ---

  // 1. 登入並抓取計畫 (需教練與學員名稱相符)
  Future<void> _loginAndFetchPlans() async {
    // 先從 controller 讀取並同步到 state
    currentUserName = nameController.text.trim();
    final traineeName = currentUserName;
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
        currentBodyFat =
            (traineeResponse[0]['body_fat'] as num?)?.toDouble() ?? 0;
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
        content: Text(message, style: TextStyle(fontFamily: fFam, color: txtCol)),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 刪除課表
  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBgCol,
        title: Text("確認刪除", style: TextStyle(fontFamily: fFam, color: txtCol)),
        content: Text(
          "確定要刪除「${plan['plan_name'] ?? '未命名課表'}」？刪除後無法復原。",
          style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("取消", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("刪除", style: TextStyle(fontFamily: fFam, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.from('workout_plans').update({'is_hidden': true}).eq('id', plan['id']);
      setState(() {
        allPlans.removeWhere((p) => p['id'] == plan['id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("課表「${plan['plan_name']}」已刪除", style: TextStyle(fontFamily: fFam)),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ 刪除課表失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗，請稍後再試', style: TextStyle(fontFamily: fFam)),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
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
        .neq('is_hidden', true) // 過濾掉已被學生隱藏的課表
        .order('created_at', ascending: false);

    // 2. 抓取歷史課表 (已完成的紀錄)
    final logsResponse = await supabase
        .from('workout_logs')
        .select(
          'id, plan_name, created_at, exercise_name, volume, weight, reps, sets, session_id, set_details, notes, total_rate, completion_rate',
        )
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
      final key = sessionId != null
          ? sessionId.toString()
          : '${dateStr}_$planName';

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

      bool isCompleted = sessionLogs.any(
        (log) => (log['exercise_name'] ?? '').contains('🏆 副本總結'),
      );
      if (isCompleted) {
        final summaryLog = sessionLogs.firstWhere(
          (log) => (log['exercise_name'] ?? '').contains('🏆 副本總結'),
        );
        final sessionNote = summaryLog['notes'] ?? '';
        final planName = summaryLog['plan_name'] ?? '未知課表';
        final dateStr = (summaryLog['created_at'] as String).substring(0, 10);

        final totalRate = (summaryLog['total_rate'] as num?)?.toDouble();
        sessionsMap[key] = {
          'date': dateStr,
          'plan_name': planName,
          'notes': sessionNote,
          'total_rate': totalRate,
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
      statsMap[key]!.sort(
        (a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
    }

    final sessionsList = sessionsMap.values.toList();
    sessionsList.sort(
      (a, b) => (b['date'] as String).compareTo(a['date'] as String),
    );

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
        .select('*, rest_time_seconds, warmup_sets, prescribed_sets, alt_prescribed_sets')
        .eq('plan_id', plan['id'])
        .order('order_index', ascending: true);
    setState(() {
      selectedPlanName = plan['plan_name'] ?? '未命名課表';
      selectedPlanId = plan['id'];
      allExercisesInPlan = response;
      exerciseCompletion = {for (int i = 0; i < response.length; i++) i: false};
      isTraining = true;
      currentSessionId =  Uuid().v4(); // 初始化新的 session ID
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
      
      // 判斷目前是否正在使用替換動作 (修正變數不一致 Bug)
      final isNowUsingAlt = ex['_is_using_alt'] == true;
      
      final rawPrescribed = isNowUsingAlt ? ex['alt_prescribed_sets'] : ex['prescribed_sets'];
      final prescribedSets = rawPrescribed is List ? rawPrescribed : [];

      if (prescribedSets.isNotEmpty) {
        currentSets = List.generate(
          prescribedSets.length,
          (i) {
            final ps = prescribedSets[i] as Map;
            return {
              "set_num": i + 1,
              "weight": (ps['weight'] as num?)?.toDouble() ?? 0.0,
              "reps": (ps['reps'] as num?)?.toInt() ?? 0,
              "rate": "0%",
            };
          }
        );
      } else {
        int numSets = ex['_current_target_sets'] ?? ex['target_sets'] ?? 3;
        double targetWeight =
            (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
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
      }
    });
  }

  // 啟動休息與達成率計算
  void _startRest(int setIdx) {
    final ex = activeExercise!;
    final isNowUsingAlt = ex['_is_using_alt'] == true;
    final prescribedSets = (isNowUsingAlt ? ex['alt_prescribed_sets'] : ex['prescribed_sets']) as List?;

    double targetWeight = 0;
    int targetReps = 0;

    if (prescribedSets != null && setIdx < prescribedSets.length) {
      final ps = prescribedSets[setIdx] as Map?;
      if (ps != null) {
        targetWeight = (ps['weight'] as num?)?.toDouble() ?? 0.0;
        targetReps = (ps['reps'] as num?)?.toInt() ?? 0;
      }
    } else {
      targetWeight = (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
      targetReps = ex['_current_target_reps'] ?? ex['target_reps'] ?? 0;
    }

    double rateValue = 0.0;
    if (targetWeight > 0) {
      double targetVol = targetWeight * targetReps;
      double actualVol = currentSets[setIdx]['weight'] * currentSets[setIdx]['reps'];
      rateValue = targetVol > 0 ? (actualVol / targetVol) : 1.0;
      print("DEBUG _startRest (idx: $setIdx) -> targetWeight: $targetWeight, targetReps: $targetReps, targetVol: $targetVol, actual: $actualVol => rate: $rateValue");
    } else {
      rateValue = targetReps > 0 ? (currentSets[setIdx]['reps'] / targetReps) : 1.0;
      print("DEBUG _startRest (idx: $setIdx) -> targetWeight: 0, targetReps: $targetReps => rate: $rateValue");
    }
    int rate = (rateValue * 100).toInt();

    setState(() {
      currentSets[setIdx]['rate'] = "$rate%";
      lastCompletionRate = "$rate%";
    });

    int restTimeSeconds = ex['rest_time_seconds'] ?? 60;
    if (prescribedSets != null && setIdx < prescribedSets.length) {
      final ps = prescribedSets[setIdx] as Map?;
      if (ps != null && ps['rest_time'] != null) {
        restTimeSeconds = (ps['rest_time'] as num).toInt();
      }
    }

    // iOS 優化：在點擊瞬間預熱全域音訊，確保權限開啟
    AudioPlayer().play(AssetSource('audio/longevity_rest.wav'), volume: 0).then((p) => p.stop());

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

    final ex = activeExercise!;
    final isNowUsingAlt = ex['_is_using_alt'] == true;
    final prescribedSets = (isNowUsingAlt ? ex['alt_prescribed_sets'] : ex['prescribed_sets']) as List?;

    double totalRateSum = 0;
    for (int i = 0; i < currentSets.length; i++) {
      var s = currentSets[i];
      
      double targetWeight = 0;
      int targetReps = 0;

      if (prescribedSets != null && i < prescribedSets.length) {
        final ps = prescribedSets[i] as Map?;
        if (ps != null) {
          targetWeight = (ps['weight'] as num?)?.toDouble() ?? 0.0;
          targetReps = (ps['reps'] as num?)?.toInt() ?? 0;
        }
      } else {
        targetWeight = (ex['_current_target_weight'] ?? ex['target_weight'] ?? 0).toDouble();
        targetReps = ex['_current_target_reps'] ?? ex['target_reps'] ?? 0;
      }

      double rateValue = 0.0;
      if (targetWeight > 0) {
        double targetVol = targetWeight * targetReps;
        double actualVol = (s['weight'] * s['reps']).toDouble();
        rateValue = targetVol > 0 ? (actualVol / targetVol) : 1.0;
        print("DEBUG _complete (idx: $i) -> targetVol: $targetVol, actual: $actualVol => rate: $rateValue");
      } else {
        rateValue = targetReps > 0 ? (s['reps'] / targetReps) : 1.0;
      }
      totalRateSum += rateValue;
    }

    double avgRate = (totalRateSum / currentSets.length) * 100;
    print("DEBUG _complete -> avgRate: $avgRate");
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
      "exercise_name":
          activeExercise!['_current_exercise_name'] ??
          (activeExercise!['_is_using_alt'] == true ? activeExercise!['alt_exercise'] : activeExercise!['exercise']),
      "weight": (currentSets.last['weight'] as num).toDouble(),
      "reps": (currentSets.last['reps'] as num).toInt(),
      "sets": currentSets.length,
      "set_details": currentSets, // 寫入詳細 JSON 結構
      "session_id": currentSessionId, // 寫入 session_id
      "completion_rate": rate,
      "volume": exerciseVolume,
      "rpe": currentRpe,
      "notes": currentExerciseNoteController.text, // 單項動作筆記
      "created_at": DateTime.now().toIso8601String(),
    };

    // 加入本地暫存，等結算一起送出
    pendingWorkoutLogs.add(logData);
    print("✅ 紀錄已暫存：$rate, 總容量: ${logData['volume']}, 備註: ${logData['notes']}");

    setState(() {
      currentExerciseNoteController.clear(); // 儲存完畢清空單項筆記
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

    final overlayStyle = isRpgMode.value
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            if (currentUserId.isEmpty)
              Expanded(child: _buildLoginForm())
            else ...[

              if (!isRpgMode.value) const SizedBox(height: 16),
              _buildCharHeader(),
              Expanded(
                child: !isTraining
                    ? _buildLobbyMode()
                    : (activeExercise == null
                        ? _buildQuestLog(totalSessionRate)
                        : _buildBattleMode()),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: (!isRpgMode.value && currentUserId.isNotEmpty && !isTraining)
          ? Container(
              padding: const EdgeInsets.only(bottom: 24), // 加入此行，將按鈕往上推，避開 Home 橫條
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: currentDashboardIndex,
                onTap: (idx) => setState(() => currentDashboardIndex = idx),
                backgroundColor: Colors.white,
                selectedItemColor: ZenColors.sageGreen,
                unselectedItemColor: ZenColors.textLight.withOpacity(0.5),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                iconSize: 28,
                selectedFontSize: 14,
                unselectedFontSize: 13,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(),
                items: const [
                  BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 2), child: Icon(Icons.dashboard_rounded)), label: "大廳"),
                  BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 2), child: Icon(Icons.fitness_center)), label: "計畫"),
                  BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 2), child: Icon(Icons.history)), label: "紀錄"),
                  BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 2), child: Icon(Icons.bar_chart)), label: "數據"),
                ],
              ),
            )
          : null,
      ),
    );
  }


  // 顯示個人資料設定對話框
  void _showProfileDialog() {
    TextEditingController heightCtrl = TextEditingController(
      text: currentHeight > 0 ? currentHeight.toString() : '',
    );
    TextEditingController weightCtrl = TextEditingController(
      text: currentWeight > 0 ? currentWeight.toString() : '',
    );
    TextEditingController bodyFatCtrl = TextEditingController(
      text: currentBodyFat > 0 ? currentBodyFat.toString() : '',
    );
    String selectedGender = ["男", "女", "不提供"].contains(currentGender)
        ? currentGender
        : "不提供";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: cardBgCol,
              title: Text("冒險者身體密碼", style: TextStyle(fontFamily: fFam, color: txtCol)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: InputDecoration(
                        labelText: "性別",
                        labelStyle: TextStyle(fontFamily: fFam, color: dimCol),
                      ),
                      dropdownColor: cardBgCol,
                      style: TextStyle(fontFamily: fFam, color: txtCol),
                      items: ["男", "女", "不提供"]
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() => selectedGender = val!);
                      },
                    ),
                    TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontFamily: fFam, color: txtCol),
                      decoration: InputDecoration(
                        labelText: "身高 (cm)",
                        labelStyle: TextStyle(fontFamily: fFam, color: dimCol),
                      ),
                    ),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontFamily: fFam, color: txtCol),
                      decoration: InputDecoration(
                        labelText: "體重 (kg)",
                        labelStyle: TextStyle(fontFamily: fFam, color: dimCol),
                      ),
                    ),
                    TextField(
                      controller: bodyFatCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontFamily: fFam, color: txtCol),
                      decoration: InputDecoration(
                        labelText: "體脂肪 (%)",
                        labelStyle: TextStyle(fontFamily: fFam, color: dimCol),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("取消", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    double newHeight = double.tryParse(heightCtrl.text) ?? 0;
                    double newWeight = double.tryParse(weightCtrl.text) ?? 0;
                    double newBodyFat = double.tryParse(bodyFatCtrl.text) ?? 0;

                    try {
                      await supabase
                          .from('users')
                          .update({
                            'gender': selectedGender,
                            'height': newHeight,
                            'weight': newWeight,
                            'body_fat': newBodyFat,
                          })
                          .eq('id', currentUserId);

                      bool metricsChanged =
                          (newWeight != currentWeight ||
                          newBodyFat != currentBodyFat);

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
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                            content: Text(
                              '資料已更新',
                              style: TextStyle(fontFamily: 'Cubic11'),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      print("Error updating profile: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: pCol),
                  child: Text("儲存", style: TextStyle(fontFamily: fFam, color: bgCol)),
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
    // 長壽模式：更緊湊、適合老人閱讀的版面
    if (!isRpgMode.value) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ZenColors.sageGreen,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              GestureDetector(
                onLongPress: () {
                  isRpgMode.value = !isRpgMode.value;
                  HapticFeedback.heavyImpact();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUserName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "累計訓練量 ${totalVolume.toStringAsFixed(0)} kg",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.manage_accounts, color: Colors.white.withOpacity(0.85), size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _showProfileDialog(),
              ),
            ],
          ),
        ),
      );
    }

    // RPG 模式：原始設計
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ZenCard(
        color: cardBgCol,
        padding: 20,
        child: Row(
          children: [
            ValueListenableBuilder<Skin>(
              valueListenable: currentSkin,
              builder: (context, skin, child) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => SkinSelectionModal(),
                    );
                  },
                  onLongPress: () {
                    isRpgMode.value = !isRpgMode.value;
                    HapticFeedback.heavyImpact();
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: pCol, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        skin.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset('assets/images/novice.png', fit: BoxFit.cover);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "⚔️ 冒險者：$currentUserName",
                        style: TextStyle(fontFamily: fFam,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.manage_accounts, color: Colors.white.withOpacity(0.7)),
                        onPressed: () => _showProfileDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "訓練量: ${totalVolume.toStringAsFixed(0)} kg",
                          style: TextStyle(fontFamily: fFam, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubViewHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: dimCol, size: 20),
            onPressed: () => setState(() => currentDashboardIndex = 0),
          ),
          Text(
            title,
            style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildZenDashboard() {
    // --- Analytics Computation ---
    // Find earliest plan (by ascending creation order — plans are fetched desc so reverse)
    final earliestPlan = allPlans.isNotEmpty
        ? allPlans.reduce((a, b) {
            final aName = (a['plan_name'] ?? '') as String;
            final bName = (b['plan_name'] ?? '') as String;
            return aName.compareTo(bName) <= 0 ? a : b;
          })
        : null;

    // Last workout date
    String lastWorkoutLabel = '尚無紀錄';
    if (historicalSessions.isNotEmpty) {
      final lastDate = historicalSessions.first['date'] as String?;
      if (lastDate != null) {
        final d = DateTime.tryParse(lastDate);
        if (d != null) {
          final diff = DateTime.now().difference(d).inDays;
          if (diff == 0) lastWorkoutLabel = '今天';
          else if (diff == 1) lastWorkoutLabel = '昨天';
          else lastWorkoutLabel = '$diff 天前';
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
                    Text("推薦計畫", style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16)),
                    Icon(Icons.fitness_center, color: Colors.white.withOpacity(0.85), size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                if (earliestPlan != null) ...[
                  Text(
                    earliestPlan['plan_name'] ?? '未命名課表',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _startWorkout(earliestPlan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ZenColors.sageGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("立即開始"),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    "恭喜已完成所有訓練！",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "請好好休息保養身體 🌿",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 17),
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
                    Text("訓練概況", style: TextStyle(color: ZenColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
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
                        color: ZenColors.sageGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.access_time_rounded, color: ZenColors.sageGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("上次運動", style: TextStyle(color: ZenColors.textLight, fontSize: 14)),
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
                        color: ZenColors.sageGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.event_repeat, color: ZenColors.sageGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("近30天運動頻率", style: TextStyle(color: ZenColors.textLight, fontSize: 14)),
                        Text('$monthlyCount 次',
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
                        color: ZenColors.sageGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.verified_outlined, color: ZenColors.sageGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("近30天平均完成率", style: TextStyle(color: ZenColors.textLight, fontSize: 14)),
                          Row(
                            children: [
                              Text(
                                rates.isEmpty ? '尚無資料' : '${monthlyAvgRate.toStringAsFixed(0)}%',
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
                                      backgroundColor: ZenColors.sageGreen.withOpacity(0.15),
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

  // 大廳選計畫 (改為 Tabbed View)
  Widget _buildLobbyMode() {
    if (!isRpgMode.value) {
      switch (currentDashboardIndex) {
        case 1:
          return Column(
            children: [
              _buildSubViewHeader("所有計畫"),
              Expanded(child: _buildFuturePlansTab()),
            ],
          );
        case 2:
          return Column(
            children: [
              _buildSubViewHeader("歷史紀錄"),
              Expanded(child: _buildHistoryTab()),
            ],
          );
        case 3:
          return Column(
            children: [
              _buildSubViewHeader("數據成就"),
              Expanded(child: _buildAchievementsTab()),
            ],
          );
        default:
          return _buildZenDashboard();
      }
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: pCol,
            unselectedLabelColor: dimCol,
            indicatorColor: pCol,
            indicatorWeight: isRpgMode.value ? 4 : 2,
            labelStyle: TextStyle(fontFamily: fFam, fontSize: 15, fontWeight: FontWeight.bold),
            tabs:  [
              Tab(text: isRpgMode.value ? "📜 任務" : "計畫"),
              Tab(text: isRpgMode.value ? "📖 紀錄" : "歷史"),
              Tab(text: isRpgMode.value ? "🏆 成就" : "成就"),
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      children: [
        ZenCard(
          child: Column(
            children: [
              Text(
                (isRpgMode.value ? "🔑 冒險者連線" : "伺服器連結"),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: fFam, 
                  color: txtCol,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: coachNameController,
                style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
                decoration: InputDecoration(
                  hintText: "教練名稱",
                  hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
                  filled: true,
                  fillColor: bgCol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.shield, color: pCol),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
                decoration: InputDecoration(
                  hintText: (isRpgMode.value ? "冒險者名稱" : "您的名字"),
                  hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
                  filled: true,
                  fillColor: bgCol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.person, color: pCol),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentUserName = nameController.text.trim();
                      currentUserId = ""; 
                      allPlans.clear();
                    });
                    _loginAndFetchPlans();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pCol,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text("進入系統", style: TextStyle(fontFamily: fFam, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFuturePlansTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        if (allPlans.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                isRpgMode.value ? "目前沒有任何分配的任務" : "暫無可選計畫",
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
                await _deletePlan(plan);
                return false; // 我們自己控制狀態，不讓 Dismissible 自動移除
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
                    plan['plan_name'] ?? '未命名課表',
                    style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 22),
                        onPressed: () => _deletePlan(plan),
                        tooltip: '刪除課表',
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: pCol.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.play_arrow, color: pCol),
                      ),
                    ],
                  ),
                  onTap: () => _startWorkout(plan),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (historicalSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            isRpgMode.value ? "沒有過去的戰役紀錄" : "暫無歷史戰績",
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
                session['plan_name'] ?? '未命名計畫',
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
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '完成 ${rate.toStringAsFixed(0)}%',
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
                  final exName = log['exercise_name'] ?? '未知動作';
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
                            "第 $setNum 組:   $weight kg   x   $reps 下",
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
                    final valueText = w > 0 ? '$w kg x $s 組 x $r 下' : '$s 組 x $r 下';
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
                    color: pCol.withOpacity(0.05),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "紀錄：$note",
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

  Widget _buildAchievementsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: pCol,
            unselectedLabelColor: Colors.grey,
            indicatorColor: pCol,
            labelStyle: TextStyle(fontFamily: fFam, fontSize: 14),
            tabs: [
              Tab(text: "動作數據"),
              Tab(text: "身體變化"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildExerciseStatsTab(), _buildBodyStatsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseStatsTab() {
    if (achievementStats.isEmpty) {
      return  Center(
        child: Text("尚未累積足夠的成就數據", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
      );
    }

    final dropdownItems = achievementStats.keys.map((exName) {
      return DropdownMenuItem(
        value: exName,
        child: Text(exName, style: TextStyle(fontFamily: fFam, color: pCol)),
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
      padding:  EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isRpgMode.value ? "📈 戰力成長曲線" : "📈 重量成長曲線",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fFam, 
              color: txtCol,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
           SizedBox(height: 20),
          Container(
            padding:  EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: pCol.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(16),
              color: isRpgMode.value ? Colors.black : Colors.white,
            ),
            child: DropdownButton<String>(
              value: selectedAchievementExercise,
              isExpanded: true,
              dropdownColor: cardBgCol,
              underline:  SizedBox(),
              items: dropdownItems,
              onChanged: (val) {
                setState(() {
                  selectedAchievementExercise = val;
                });
              },
            ),
          ),
           SizedBox(height: 16),
          if (spots.isEmpty)
             Center(
              child: Text("此項目無有效數據", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
            )
          else ...[
            if (chartData.length > 10)
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe, size: 14, color: dimCol),
                    SizedBox(width: 4),
                    Text(
                      "橫向滑動查看全部",
                      style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 11),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Builder(
                builder: (context) {
                   int windowSize = 10;
                  final bool needsScroll = chartData.length > windowSize;
                  final double maxX = needsScroll
                      ? spots.length.toDouble() - 1
                      : max(windowSize.toDouble() - 1, 1);

                  Widget chartWidget = LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: dimCol, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (val, meta) => Text(
                                val.toInt().toString(),
                                style: TextStyle(fontFamily: fFam, 
                                  color: dimCol,
                                  fontSize: 10,
                                ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              int idx = value.toInt();
                              if (idx >= 0 && idx < chartData.length) {
                                final rawDate =
                                    chartData[idx]['created_at'] as String?;
                                if (rawDate != null && rawDate.length >= 10) {
                                  return Padding(
                                    padding:  EdgeInsets.only(top: 5.0),
                                    child: Text(
                                      rawDate
                                          .substring(5, 10)
                                          .replaceFirst('-', '/'),
                                      style: TextStyle(fontFamily: fFam, 
                                        color: Colors.grey,
                                        fontSize: 8,
                                      ),
                                    ),
                                  );
                                }
                              }
                              return  SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles:  AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles:  AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: maxVol * 1.2,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: pCol,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData:  FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: pCol.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (needsScroll) {
                    final double chartWidth = spots.length * 44.0;
                    return InteractiveViewer(
                      constrained: false,
                      scaleEnabled: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: chartWidth, child: chartWidget),
                      ),
                    );
                  }
                  return chartWidget;
                },
              ),
            ),
          ],
           SizedBox(height: 20),
          Text(
            "說明：縱軸為該動作的最高重量 (若無重量則為次數)\\n橫軸為歷史訓練次數 (由左至右為舊到新)",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fFam, color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // 副本任務佈告欄
  Widget _buildQuestLog(double finalRate) {
    bool allDone = exerciseCompletion.values.every((v) => v == true);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: dimCol),
              onPressed: () =>
                  setState(() => isTraining = false), // Go back to lobby
            ),
            Expanded(
              child: Text(
                (isRpgMode.value ? "🏰 副本：$selectedPlanName" : "當前計畫：$selectedPlanName"),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 48), 
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(allExercisesInPlan.length, (index) {
          final ex = allExercisesInPlan[index];
          bool isDone = exerciseCompletion[index] ?? false;

          bool hasAlt =
              ex['alt_exercise'] != null &&
              ex['alt_exercise'].toString().isNotEmpty;
          bool isUsingAlt = ex['_is_using_alt'] == true; 

          String displayExName = isUsingAlt
              ? ex['alt_exercise']
              : (ex['exercise'] ?? '動作');
          List<dynamic> psets = isUsingAlt
              ? (ex['alt_prescribed_sets'] ?? [])
              : (ex['prescribed_sets'] ?? []);
          
          int displaySets = isUsingAlt ? (ex['alt_target_sets'] ?? ex['target_sets'] ?? 0) : (ex['target_sets'] ?? 0);
          int displayReps = isUsingAlt ? (ex['alt_target_reps'] ?? ex['target_reps'] ?? 0) : (ex['target_reps'] ?? 0);
          num displayWeight = isUsingAlt ? (ex['alt_target_weight'] ?? ex['target_weight'] ?? 0) : (ex['target_weight'] ?? 0);

          if (psets.isNotEmpty) {
            displaySets = psets.length;
            displayReps = (psets[0]['reps'] as num?)?.toInt() ?? 0;
            displayWeight = (psets[0]['weight'] as num?) ?? 0;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ZenCard(
              padding: 4,
              color: isDone ? Colors.green.withOpacity(0.05) : cardBgCol,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? Colors.green : dimCol,
                      size: 28,
                    ),
                    title: Text(
                      displayExName,
                      style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold),
                    ),
                    subtitle: isDone
                        ? Text(
                            "達成率 : ${exerciseFinalRates[index] ?? '0%'}",
                            style: TextStyle(fontFamily: fFam, color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                          )
                        : Text(
                            "$displaySets 組 $displayReps 下",
                            style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 13),
                          ),
                    trailing: isDone ? null : Icon(Icons.play_arrow_rounded, color: pCol, size: 30),
                    onTap: isDone
                        ? null
                        : () {
                            ex['_current_exercise_name'] = displayExName;
                            ex['_current_target_sets'] = displaySets;
                            ex['_current_target_reps'] = displayReps;
                            ex['_current_target_weight'] = displayWeight;
                            _enterExercise(ex, index);
                          },
                  ),
                  if (!isDone && hasAlt)
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              ex['_is_using_alt'] = !isUsingAlt;
                            });
                          },
                          icon: Icon(Icons.swap_horiz, size: 16, color: pCol),
                          label: Text(
                            isUsingAlt ? "切換回原動作" : "切換替換動作",
                            style: TextStyle(fontFamily: fFam, color: pCol, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: pCol.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        if (allDone && allExercisesInPlan.isNotEmpty)
          _buildFinalSummary(finalRate),
      ],
    );
  }

  Widget _buildRpeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [2, 4, 6, 8, 10]
            .map(
              (val) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text("RPE $val", style: TextStyle(fontFamily: fFam, fontWeight: FontWeight.bold)),
                  selected: currentRpe == val,
                  selectedColor: pCol.withOpacity(0.2),
                  onSelected: (bool selected) {
                    setState(() => currentRpe = val);
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // 戰鬥畫面 (做動作)
  Widget _buildBattleMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: dimCol),
                onPressed: () {
                  setState(() {
                    activeExercise = null; // 回到副本清單
                    currentExerciseNoteController.clear();
                  });
                },
              ),
              Expanded(
                child: Text(
                  "${activeExercise!['_current_exercise_name'] ?? (activeExercise!['_is_using_alt'] == true ? (activeExercise!['alt_exercise'] ?? activeExercise!['exercise']) : activeExercise!['exercise'])}",
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
              hintText: "動作備註 (選填)：做起來的感覺如何？",
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
              onPressed: _completeActiveExercise,
              child: Text(
                (isRpgMode.value ? "領取經驗值" : "完成動作"),
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

  // 組數調整卡片
  Widget _buildSetCard(int i) {
    return ZenCard(
      padding: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "組回 ${i + 1}",
                style: TextStyle(fontFamily: fFam, color: pCol, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (currentSets[i]['rate'] != "")
                Text(
                  "達成: ${currentSets[i]['rate']}",
                  style: TextStyle(fontFamily: fFam, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              IconButton(
                icon: Icon(Icons.timer_outlined, color: Colors.green),
                onPressed: () => _startRest(i),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAdjuster(i, "weight", 0.5, "kg"),
              Container(width: 1, height: 30, color: dimCol.withOpacity(0.2)),
              _buildAdjuster(i, "reps", 1, "下"),
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
          onPressed: () => setState(() => currentSets[i][key] -= delta),
        ),
        Text(
          "${currentSets[i][key]}$unit",
          style: TextStyle(fontFamily: fFam, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline),
          onPressed: () => setState(() => currentSets[i][key] += delta),
        ),
      ],
    );
  }

  // 副本結算與備註
  // 🚀 修改這個方法，讓它能接收總分並存檔
  Widget _buildFinalSummary(double finalScore) {
    return ZenCard(
      color: pCol.withOpacity(0.05),
      padding: 24,
      child: Column(
        children: [
          Text(
            (isRpgMode.value ? "🏆 任務結算" : "本次訓練總結"),
            style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "總達成率: ",
                style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 16),
              ),
              Text(
                "${finalScore.toStringAsFixed(1)}%",
                style: TextStyle(fontFamily: fFam, color: Colors.orange, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "全課表疲勞度 (RPE)：",
                style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "$currentRpe",
                style: TextStyle(fontFamily: fFam, 
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "1-10 分，1 分最輕鬆，10 分是最累",
            style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildRpeSelector(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text("附註留言 (選填)", style: TextStyle(fontFamily: fFam, color: txtCol, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "記錄今天的感想或有疑慮的地方...",
              hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
              filled: true,
              fillColor: isRpgMode.value ? Colors.black : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
           SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pCol, // 亮綠色
              foregroundColor: bgCol, // 黑色文字
              padding:  EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  'rpe': currentRpe, // 全局 RPE
                  'session_id': currentSessionId, // 掛鉤同一個 session
                  'created_at': DateTime.now().toIso8601String(),
                };

                // 合併全部要上傳的資料
                List<Map<String, dynamic>> allLogsToUpload = List.from(
                  pendingWorkoutLogs,
                );
                allLogsToUpload.add(summaryLog);

                // 一次上傳
                await supabase.from('workout_logs').insert(allLogsToUpload);
                
                // 播放上傳成功音效
                final summaryPlayer = AudioPlayer();
                await summaryPlayer.play(AssetSource('audio/upload_data.wav'));
                
                print("✅ 結算與動作紀錄存檔成功！");

                // 將該筆課表標示為完成，避免重複執行並保留供教練複製
                if (selectedPlanId.isNotEmpty) {
                  await supabase
                      .from('workout_plans')
                      .update({'is_completed': true})
                      .eq('id', selectedPlanId);
                  print("✅ 課表已標示為完成！");
                }
              } catch (e) {
                print("❌ 資料存檔或刪除失敗：$e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("數據上傳失敗: $e"),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
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
              isRpgMode.value ? "上傳數據並回村莊" : "上傳數據",
              style: TextStyle(fontFamily: fFam, 
                color: bgCol,
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
      return  Center(
        child: Text(
          "尚未記錄任何身體數據，請點擊上方頭像旁的設定按鈕新增。",
          style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
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
      padding:  EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "💪 體重變化與體脂走勢",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fFam, 
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
           SizedBox(height: 20),
          if (weightSpots.isEmpty && fatSpots.isEmpty)
             Center(
              child: Text("目前無記錄", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
            )
          else
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: dimCol, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        "數值",
                        style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 10),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles:  AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles:  AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles:  AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: maxWeight > 0 || maxFat > 0
                      ? max(
                          weightSpots.length > fatSpots.length
                              ? weightSpots.length.toDouble() - 1
                              : fatSpots.length.toDouble() - 1,
                          1.0,
                        )
                      : 1.0,
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
           SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, color: Colors.blueAccent),
               SizedBox(width: 8),
              Text(
                "體重 (kg)",
                style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 12),
              ),
               SizedBox(width: 20),
              Container(width: 12, height: 12, color: Colors.redAccent),
               SizedBox(width: 8),
              Text(
                "體脂 (%)",
                style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkinSelectionModal extends StatefulWidget {
   SkinSelectionModal({super.key});

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
        backgroundColor: cardBgCol,
        title: Text("更換造型確認", style: TextStyle(fontFamily: fFam, color: txtCol)),
        content: Text(
          "確定要更換造型為 ${skin.name} 嗎？",
          style: TextStyle(fontFamily: fFam, color: dimCol),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor:  const Color(0xFFD72B2B), // Brave Red
            ),
            child: Text("取消", style: TextStyle(fontFamily: 'Cubic11')),
          ),
          TextButton(
            onPressed: () {
              // Sync state
              currentSkin.value = skin;
              Navigator.pop(context); // Close dialog
              // Modal stays open as requested
            },
            style: TextButton.styleFrom(
              foregroundColor:  const Color(0xFF2975C6), // Knight Blue
            ),
            child: Text("確定", style: TextStyle(fontFamily: 'Cubic11')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      insetPadding: EdgeInsets.zero, // Full screen modal
      child: Container(
        padding:  EdgeInsets.all(20),
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: txtCol),
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
                            color:  const Color(0xFF2975C6), // Knight Blue
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
                   SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () =>
                        _showConfirmationDialog(selectedPreviewSkin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:  const Color(0xFF2975C6), // Knight Blue
                      foregroundColor: txtCol,
                    ),
                    child: Text("更換為大頭像", style: TextStyle(fontFamily: fFam, fontSize: 16)),
                  ),
                ],
              ),
            ),

             SizedBox(height: 20),
            Text("選擇造型", style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 20)),
             SizedBox(height: 10),

            // Selection Area (Grid)
            Expanded(
              flex: 3,
              child: GridView.builder(
                gridDelegate:  SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8, // Fixed ratio to prevent stretching
                ),
                itemCount: allSkins.length,
                itemBuilder: (context, index) {
                  final skin = allSkins[index];
                  final isSelected =
                      skin.id == selectedPreviewSkin.id; // Correct comparsion

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
                            ? Border.all(
                                color:  const Color(0xFF2975C6),
                                width: 4,
                              )
                            : Border.all(color: Colors.grey, width: 1),
                        color: dimCol,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding:  EdgeInsets.all(8.0),
                              child: Image.asset(
                                skin.imagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image_not_supported,
                                    color: txtCol,
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            skin.name,
                            style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 12),
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

   RestTimerDialog({super.key, required this.restTimeSeconds});

  @override
  State<RestTimerDialog> createState() => _RestTimerDialogState();
}

class _RestTimerDialogState extends State<RestTimerDialog> {
  late DateTime endTime;
  late Timer timer;
  int remainingSeconds = 0;
  bool isFinished = false;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.restTimeSeconds;
    endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    
    // 初始化並預設為可與背景音樂混合的模式
    _audioPlayer = AudioPlayer();
    _audioPlayer?.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient, // 預熱時使用 ambient
      ),
      android: AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    ));
    _prewarmAudio();

    timer = Timer.periodic( Duration(seconds: 1), (Timer t) {
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
        _playRingtone();
      } else {
        setState(() {
          remainingSeconds = endTime.difference(now).inSeconds;
        });
      }
    });
  }

  // 預先播放解除限制
  Future<void> _prewarmAudio() async {
    try {
      // 設定音量為 0，播放一瞬間就暫停，解鎖播放權限
      await _audioPlayer?.setVolume(0);
      String audioFile = isRpgMode.value ? 'audio/rpg_rest.wav' : 'audio/longevity_rest.wav';
      await _audioPlayer?.play(AssetSource(audioFile));
      await Future.delayed(const Duration(milliseconds: 50));
      await _audioPlayer?.pause();
      // 將音量恢復為正常值 1.0 (最大音量)
      await _audioPlayer?.setVolume(1.0);
    } catch (e) {
      print("Audio prewarm failed: $e");
    }
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
        await Future.delayed( Duration(milliseconds: 400));
        Vibration.vibrate();
        await Future.delayed( Duration(milliseconds: 400));
        Vibration.vibrate();
      }
    } else {
      // Final fallback using system HapticFeedback
      HapticFeedback.heavyImpact();
      await Future.delayed( Duration(milliseconds: 400));
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _playRingtone() async {
    try {
      // 當時間到的時候，切換到會降低其他音樂音量 (Duck) 的模式
      await _audioPlayer?.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback, // 切換到 playback 以便 ducking
          options: {
            AVAudioSessionOptions.duckOthers,
            AVAudioSessionOptions.interruptSpokenAudioAndMixWithOthers,
          },
        ),
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.notificationEvent, // 使用通知類別
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));

      // 確保音量是滿的，將原本預熱用的音效進度歸零後播放
      await _audioPlayer?.setVolume(1.0);
      
      // 保險起見，重新 play (Web 版建議先 setSource 再 resume 或再次 play)
      String audioFile = isRpgMode.value ? 'audio/rpg_rest.wav' : 'audio/longevity_rest.wav';
      await _audioPlayer?.stop(); // 先停止之前的 (如果有)
      await _audioPlayer?.play(AssetSource(audioFile));
    } catch (e) {
      print("Play ringtone failed: $e");
    }
  }

  @override
  void dispose() {
    timer.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardBgCol,
      title: Text(
        "休息時間",
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 24),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFinished ? "時間到！" : "💖 體力回復中...",
            style: TextStyle(fontFamily: fFam, color: isFinished ? pCol : dimCol, fontSize: 18),
          ),
           SizedBox(height: 20),
          Text(
            "$remainingSeconds s",
            style: TextStyle(fontFamily: fFam, 
              color: isFinished ? pCol : Colors.orange,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isFinished) ...[
             SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _playRingtone(),
              icon:  Icon(Icons.volume_up, color: pCol),
              label: Text("點此再次播放音效", style: TextStyle(fontFamily: fFam, color: pCol)),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () {
            _audioPlayer?.stop();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: pCol,
            foregroundColor: bgCol,
            padding:  EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: Text(
            "停止休息，進行下一個",
            style: TextStyle(fontFamily: fFam, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
