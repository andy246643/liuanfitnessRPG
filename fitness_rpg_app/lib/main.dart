import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';

// 新架構 imports
import 'theme/zen_theme.dart';
import 'widgets/rest_timer_dialog.dart';
import 'widgets/char_header.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_view.dart';
import 'screens/plans_view.dart';
import 'screens/history_view.dart';
import 'screens/stats_view.dart';
import 'screens/training_screen.dart';
import 'screens/exercise_screen.dart';
import 'services/auth_service.dart';
import 'services/workout_service.dart';
import 'services/stats_service.dart';
import 'services/local_storage_service.dart';
import 'services/energy_service.dart';
import 'models/rpg_character.dart';

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

  // 設定全域音訊上下文，確保行動裝置播放穩定
  try {
    AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.duckOthers,
          AVAudioSessionOptions.interruptSpokenAudioAndMixWithOthers,
        },
      ),
      android: AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    ));
  } catch (e) {
    debugPrint('⚠️ Warning: AudioPlayer global context setup failed: $e');
  }

  runApp(const FitnessRPGApp());
}

// Theme, ZenCard, 色彩等已移至 theme/zen_theme.dart 和 widgets/zen_card.dart

class FitnessRPGApp extends StatelessWidget {
   const FitnessRPGApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isRpgMode,
      builder: (context, isRpg, child) {
        return MaterialApp(
          theme: isRpg ? buildRpgTheme() : buildLongevityTheme(),
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
  bool _isUploading = false; // 上傳狀態旗標

  // 5. RPG 角色狀態
  RpgCharacter? rpgCharacter;
  double _cachedTotalSessionRate = 0; // 快取的總達成率，避免在 build() 重算

  @override
  void initState() {
    super.initState();
  }

  // --- 快取計算 ---
  void _updateSessionRate() {
    if (exerciseFinalRates.isEmpty) {
      _cachedTotalSessionRate = 0;
      return;
    }
    double sum = 0;
    for (final rateString in exerciseFinalRates.values) {
      sum += double.tryParse(rateString.replaceAll('%', '')) ?? 0;
    }
    _cachedTotalSessionRate = sum / exerciseFinalRates.length;
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
      debugPrint("成功登入：$traineeName (ID: $currentUserId)");

      // 拿到 currentUserId 後繼續抓取計畫
      await _fetchPlans();

      // 檢查是否有未上傳的暫存訓練紀錄
      await _checkPendingRecovery();
    } catch (e) {
      debugPrint("登入發生錯誤: $e");
      _showLoginError("連線錯誤，請稍後再試。");
    }
  }

  Future<void> _checkPendingRecovery() async {
    final pendingLogs = await LocalStorageService.loadPendingLogs();
    if (pendingLogs.isEmpty || !mounted) return;

    final shouldRecover = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBgCol,
        title: Text("發現未完成的訓練", style: TextStyle(fontFamily: fFam, color: txtCol)),
        content: Text(
          "上次有 ${pendingLogs.length} 筆訓練紀錄尚未上傳。\n要恢復並重新上傳嗎？",
          style: TextStyle(fontFamily: fFam, color: dimCol),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("捨棄", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: pCol),
            child: Text("恢復上傳", style: TextStyle(fontFamily: fFam, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldRecover == true) {
      try {
        await supabase.from('workout_logs').insert(pendingLogs);
        await LocalStorageService.clearPendingLogs();
        await LocalStorageService.clearSessionState();
        await _fetchPlans();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("已成功恢復 ${pendingLogs.length} 筆訓練紀錄！", style: TextStyle(fontFamily: fFam)),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        debugPrint("恢復上傳失敗: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("恢復上傳失敗，資料仍保留在本地，下次登入會再次詢問"), backgroundColor: Colors.orange),
          );
        }
      }
    } else {
      await LocalStorageService.clearPendingLogs();
      await LocalStorageService.clearSessionState();
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
      debugPrint('刪除課表失敗: $e');
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

    // 併行抓取 1.未來課表 2.歷史紀錄 3.身體指標（各自獨立失敗不影響其他）
    late List response;
    late List<Map<String, dynamic>> logs;
    late List<Map<String, dynamic>> metricsList;

    final futures = await Future.wait([
      supabase
          .from('workout_plans')
          .select('id, plan_name')
          .eq('user_id', currentUserId)
          .eq('is_completed', false)
          .neq('is_hidden', true)
          .order('created_at', ascending: false)
          .then<List>((v) => v, onError: (e) { debugPrint('課表載入失敗: $e'); return <dynamic>[]; }),
      supabase
          .from('workout_logs')
          .select('id, plan_name, created_at, exercise_name, volume, weight, reps, sets, session_id, set_details, notes, total_rate, completion_rate')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(200)
          .then<List>((v) => v, onError: (e) { debugPrint('紀錄載入失敗: $e'); return <dynamic>[]; }),
      supabase
          .from('user_metrics_history')
          .select('weight, body_fat, created_at')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: true)
          .limit(100)
          .then<List>((v) => v, onError: (e) { debugPrint('指標載入失敗: $e'); return <dynamic>[]; }),
    ]);

    response = futures[0];
    logs = List<Map<String, dynamic>>.from(futures[1]);
    metricsList = List<Map<String, dynamic>>.from(futures[2]);

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
      achievementStats = StatsService.aggregateDailyMax(statsMap);
      if (achievementStats.isNotEmpty && selectedAchievementExercise == null) {
        selectedAchievementExercise = achievementStats.keys.first;
      }
    });

    // 載入 RPG 角色
    try {
      final char = await EnergyService.loadOrCreateCharacter(currentUserId);
      if (mounted) setState(() => rpgCharacter = char);
    } catch (e) {
      debugPrint('RPG 角色載入失敗: $e');
    }
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

  // 點擊任務進入特定動作（支援重新編輯已完成動作）
  void _enterExercise(dynamic ex, int index) {
    setState(() {
      activeExercise = ex;
      activeExerciseIndex = index;
      currentRpe = 8;

      final bool wasCompleted = exerciseCompletion[index] == true;

      // 如果是重新編輯已完成動作，從 pendingWorkoutLogs 載入之前的資料
      if (wasCompleted) {
        final exerciseName = ex['_current_exercise_name'] ??
            (ex['_is_using_alt'] == true ? ex['alt_exercise'] : ex['exercise']);
        final existingLog = pendingWorkoutLogs.lastWhere(
          (log) => log['exercise_name'] == exerciseName,
          orElse: () => <String, dynamic>{},
        );

        if (existingLog.isNotEmpty && existingLog['set_details'] != null) {
          final savedSets = existingLog['set_details'] as List;
          currentSets = List.generate(savedSets.length, (i) {
            final s = savedSets[i] as Map;
            return {
              "set_num": i + 1,
              "weight": (s['weight'] as num?)?.toDouble() ?? 0.0,
              "reps": (s['reps'] as num?)?.toInt() ?? 0,
              "rate": s['rate'] ?? "0%",
            };
          });
          // 載入之前的 RPE 和筆記
          currentRpe = (existingLog['rpe'] as int?) ?? 8;
          if (existingLog['notes'] != null) {
            currentExerciseNoteController.text = existingLog['notes'] as String;
          }
          exerciseCompletion[index] = false; // 重新啟用
          return;
        }
      }

      // 正常初始化（首次進入動作）
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
      debugPrint("_startRest (idx: $setIdx) -> targetVol: $targetVol, actual: $actualVol => rate: $rateValue");
    } else {
      rateValue = targetReps > 0 ? (currentSets[setIdx]['reps'] / targetReps) : 1.0;
      debugPrint("_startRest (idx: $setIdx) -> targetReps: $targetReps => rate: $rateValue");
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
        debugPrint("_complete (idx: $i) -> targetVol: $targetVol, actual: $actualVol => rate: $rateValue");
      } else {
        rateValue = targetReps > 0 ? (s['reps'] / targetReps) : 1.0;
      }
      totalRateSum += rateValue;
    }

    double avgRate = (totalRateSum / currentSets.length) * 100;
    debugPrint("_complete -> avgRate: $avgRate");
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

    // 加入本地暫存（如果同一動作已有紀錄則替換，避免重複）
    final exerciseName = logData['exercise_name'];
    final existingIdx = pendingWorkoutLogs.indexWhere(
      (log) => log['exercise_name'] == exerciseName,
    );
    if (existingIdx >= 0) {
      pendingWorkoutLogs[existingIdx] = logData;
      debugPrint("紀錄已更新（替換）：$rate, 總容量: ${logData['volume']}");
    } else {
      pendingWorkoutLogs.add(logData);
      debugPrint("紀錄已暫存（新增）：$rate, 總容量: ${logData['volume']}");
    }
    LocalStorageService.savePendingLogs(pendingWorkoutLogs);

    setState(() {
      currentExerciseNoteController.clear();
      exerciseFinalRates[activeExerciseIndex!] = rate;
      exerciseCompletion[activeExerciseIndex!] = true;
      // 重新計算 totalVolume（從所有 pendingWorkoutLogs 加總，避免編輯時重複計算）
      double recalcVol = 0;
      for (var log in pendingWorkoutLogs) {
        final details = log['set_details'] as List?;
        if (details != null) {
          for (var s in details) {
            double w = (s['weight'] as num?)?.toDouble() ?? 0;
            int r = (s['reps'] as num?)?.toInt() ?? 0;
            recalcVol += (w > 0) ? (w * r) : (r * 10);
          }
        }
      }
      totalVolume = recalcVol;
      _updateSessionRate(); // 預先計算快取
      activeExercise = null;
      activeExerciseIndex = null;
    });
  }

  // --- UI 區 ---

  Widget _buildLobbyMode() {
    switch (currentDashboardIndex) {
      case 0:
        return DashboardView(
          allPlans: allPlans,
          historicalSessions: historicalSessions,
          totalVolume: totalVolume,
          onStartWorkout: _startWorkout,
          rpgCharacter: rpgCharacter,
        );
      case 1:
        return PlansView(
          allPlans: allPlans,
          onStartWorkout: _startWorkout,
          onDeletePlan: _deletePlan,
        );
      case 2:
        return HistoryView(historicalSessions: historicalSessions);
      case 3:
        return StatsView(
          achievementStats: achievementStats,
          weightHistory: weightHistory,
          bodyFatHistory: bodyFatHistory,
        );
      default:
        return DashboardView(
          allPlans: allPlans,
          historicalSessions: historicalSessions,
          totalVolume: totalVolume,
          onStartWorkout: _startWorkout,
          rpgCharacter: rpgCharacter,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSessionRate = _cachedTotalSessionRate;

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
              Expanded(child: LoginScreen(
                onLogin: (traineeName, coachName) {
                  nameController.text = traineeName;
                  coachNameController.text = coachName;
                  setState(() {
                    currentUserName = traineeName;
                    currentUserId = "";
                    allPlans.clear();
                  });
                  _loginAndFetchPlans();
                },
              ))
            else ...[

              if (!isRpgMode.value) const SizedBox(height: 16),
              CharHeader(
                currentUserName: currentUserName,
                totalVolume: totalVolume,
                onProfileTap: () => _showProfileDialog(),
                onThemeToggle: () {
                  isRpgMode.value = !isRpgMode.value;
                },
              ),
              Expanded(
                child: !isTraining
                    ? _buildLobbyMode()
                    : (activeExercise == null
                        ? TrainingScreen(
                            selectedPlanName: selectedPlanName,
                            allExercisesInPlan: allExercisesInPlan,
                            exerciseCompletion: exerciseCompletion,
                            exerciseFinalRates: exerciseFinalRates,
                            onExerciseTap: _enterExercise,
                            onBackToLobby: () => setState(() => isTraining = false),
                            noteController: noteController,
                            currentRpe: currentRpe,
                            onRpeChanged: (val) => setState(() => currentRpe = val),
                            totalSessionRate: totalSessionRate,
                            isUploading: _isUploading,
                            onFinishWorkout: () => _finishWorkout(totalSessionRate),
                          )
                        : ExerciseScreen(
                            activeExercise: activeExercise!,
                            currentSets: currentSets,
                            selectedPlanName: selectedPlanName,
                            onCompleteExercise: _completeActiveExercise,
                            onStartRest: _startRest,
                            onSetChanged: (i, key, delta) {
                              setState(() => currentSets[i][key] += delta);
                            },
                            currentExerciseNoteController: currentExerciseNoteController,
                            onBack: () {
                              setState(() {
                                activeExercise = null;
                                currentExerciseNoteController.clear();
                              });
                            },
                          )),
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
                  BoxShadow(color: ZenColors.black05, blurRadius: 20, offset: const Offset(0, -5))
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: currentDashboardIndex,
                onTap: (idx) => setState(() => currentDashboardIndex = idx),
                backgroundColor: Colors.white,
                selectedItemColor: ZenColors.sageGreen,
                unselectedItemColor: ZenColors.textLight50,
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
                      debugPrint("Error updating profile: $e");
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

  // Upload finish workout logic (extracted from _buildFinalSummary onPressed)
  Future<void> _finishWorkout(double finalScore) async {
    setState(() => _isUploading = true);

    // 1. Play upload sound (don't await to avoid blocking)
    try {
      final summaryPlayer = AudioPlayer();
      summaryPlayer.play(AssetSource('audio/上傳數據.wav'));
    } catch (audioError) {
      debugPrint("Upload audio play failed: $audioError");
    }

    // 2. Upload pending logs + summary to cloud
    try {
      String finalRateString = "${finalScore.toStringAsFixed(0)}%";

      final summaryLog = {
        'user_id': currentUserId,
        'plan_name': selectedPlanName,
        'exercise_name': '🏆 副本總結結算',
        'completion_rate': finalRateString,
        'total_rate': finalScore,
        'notes': noteController.text,
        'rpe': currentRpe,
        'session_id': currentSessionId,
        'created_at': DateTime.now().toIso8601String(),
      };

      List<Map<String, dynamic>> allLogsToUpload = List.from(pendingWorkoutLogs);
      allLogsToUpload.add(summaryLog);

      List<Future> uploadTasks = [
        supabase.from('workout_logs').insert(allLogsToUpload)
      ];

      if (selectedPlanId.isNotEmpty) {
        uploadTasks.add(
          supabase
              .from('workout_plans')
              .update({'is_completed': true})
              .eq('id', selectedPlanId)
        );
      }

      await Future.wait(uploadTasks);
      debugPrint("數據併行上傳成功");

      // --- RPG: 計算並發放能量 ---
      AwardResult? rpgResult;
      try {
        final exerciseInputs = pendingWorkoutLogs.map((log) {
          return ExerciseEnergyInput(
            exerciseName: log['exercise_name'] ?? '',
            sets: List<Map<String, dynamic>>.from(log['set_details'] ?? []),
          );
        }).toList();

        final isCoachPlan = selectedPlanId.isNotEmpty;
        final streakDays = rpgCharacter?.streakDays ?? 0;

        final energyResult = EnergyService.calculateSessionEnergy(
          exerciseLogs: exerciseInputs,
          isCoachPlan: isCoachPlan,
          streakDays: streakDays,
        );

        rpgResult = await EnergyService.awardEnergy(
          userId: currentUserId,
          sessionId: currentSessionId,
          energyResult: energyResult,
        );
      } catch (e) {
        debugPrint("RPG 能量發放失敗（不影響紀錄）: $e");
      }

      setState(() {
        isTraining = false;
        _isUploading = false;
        noteController.clear();
        pendingWorkoutLogs.clear();
        currentDashboardIndex = 0; // 回到大廳
      });
      await LocalStorageService.clearPendingLogs();
      await LocalStorageService.clearSessionState();

      await _fetchPlans();

      if (mounted) {
        // 顯示 RPG 結果或基本完成提示
        if (rpgResult != null) {
          final levelUpText = rpgResult.leveledUp ? ' 升級到 Lv.${rpgResult.newLevel}！' : '';
          final streakText = rpgResult.streakDays > 1 ? ' 連續${rpgResult.streakDays}天' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "訓練完成！+${rpgResult.energyEarned} 能量$levelUpText$streakText",
                style: TextStyle(fontFamily: fFam),
              ),
              backgroundColor: rpgResult.leveledUp ? Colors.amber.shade700 : Colors.green.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("訓練完成！總達成率 ${finalScore.toStringAsFixed(0)}%", style: TextStyle(fontFamily: fFam)),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("資料存檔或刪除失敗：$e");
      setState(() => _isUploading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("數據上傳失敗，請檢查網路連線後重試"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

