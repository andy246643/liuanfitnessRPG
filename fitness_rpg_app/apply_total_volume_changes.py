import re

def main():
    path = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. State Variables
    old_vars = """  // 1. RPG 基礎狀態
  int level = 1;
  int totalXp = 0;
  int currentRpe = 8;"""
    new_vars = """  // 1. RPG 基礎狀態
  double totalVolume = 0;
  String currentGender = "不提供";
  double currentHeight = 0;
  double currentWeight = 0;
  double currentBodyFat = 0;
  List<Map<String, dynamic>> weightHistory = [];
  List<Map<String, dynamic>> bodyFatHistory = [];
  int currentRpe = 8;"""
    content = content.replace(old_vars, new_vars)

    # 2. _loginAndFetchPlans query
    old_trainee_query = """      final traineeResponse = await supabase
          .from('users')
          .select('id, name')
          .ilike('name', traineeName)
          .eq('role', 'trainee')
          .eq('coach_id', coachId)
          .limit(1);"""
    new_trainee_query = """      final traineeResponse = await supabase
          .from('users')
          .select('id, name, gender, height, weight, body_fat')
          .ilike('name', traineeName)
          .eq('role', 'trainee')
          .eq('coach_id', coachId)
          .limit(1);"""
    content = content.replace(old_trainee_query, new_trainee_query)

    # 3. _loginAndFetchPlans setState
    old_set_state_login = """      setState(() {
        currentUserId = traineeResponse[0]['id'];
      });"""
    new_set_state_login = """      setState(() {
        currentUserId = traineeResponse[0]['id'];
        currentGender = traineeResponse[0]['gender'] ?? "不提供";
        currentHeight = (traineeResponse[0]['height'] as num?)?.toDouble() ?? 0;
        currentWeight = (traineeResponse[0]['weight'] as num?)?.toDouble() ?? 0;
        currentBodyFat = (traineeResponse[0]['body_fat'] as num?)?.toDouble() ?? 0;
      });"""
    content = content.replace(old_set_state_login, new_set_state_login)

    # 4. _fetchPlans history fetching
    old_fetch_logs = """    final logsResponse = await supabase
        .from('workout_logs')
        .select('id, plan_name, created_at, exercise_name, volume, weight, reps, sets, session_id, set_details, notes')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);
        
    final logs = List<Map<String, dynamic>>.from(logsResponse);"""
    new_fetch_logs = """    final logsResponse = await supabase
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
    final logs = List<Map<String, dynamic>>.from(logsResponse);"""
    content = content.replace(old_fetch_logs, new_fetch_logs)

    # 5. Volume Calculation inside _fetchPlans
    old_stats_sort = """    // 排序成就資料 (由舊到新)
    for (var key in statsMap.keys) {
       statsMap[key]!.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    }
    
    final sessionsList = sessionsMap.values.toList();
    sessionsList.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    setState(() {"""
    new_stats_sort = """    // 計算 Total Volume
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
      bodyFatHistory = metricsList.where((m) => m['body_fat'] != null).toList();"""
    content = content.replace(old_stats_sort, new_stats_sort)

    # 6. _completeActiveExercise
    old_xp_logic = """    setState(() {
      exerciseFinalRates[activeExerciseIndex!] = rate;
      exerciseCompletion[activeExerciseIndex!] = true;
      totalXp += 20;
      if (totalXp >= 100) {
        level++;
        totalXp = 0;
      }
      activeExercise = null;
      activeExerciseIndex = null;
    });"""
    new_xp_logic = """    setState(() {
      exerciseFinalRates[activeExerciseIndex!] = rate;
      exerciseCompletion[activeExerciseIndex!] = true;
      for (var s in currentSets) {
        double w = (s['weight'] as num).toDouble();
        int r = (s['reps'] as num).toInt();
        totalVolume += (w > 0) ? (w * r) : (r * 10);
      }
      activeExercise = null;
      activeExerciseIndex = null;
    });"""
    content = content.replace(old_xp_logic, new_xp_logic)

    # 7. UI updates in _buildCharHeader
    old_header = """          // --- 2. 右側：冒險者資訊 (就是你原本的那段 Column) ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "⚔️ 冒險者：$currentUserName",
                  style: TextStyle(fontFamily: 'Cubic11',
                    color: Theme.of(context).primaryColor,
                    fontSize: 22, // 稍微縮小一點點以適應排版
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: totalXp / 100,
                  color: Theme.of(context).primaryColor,
                  backgroundColor: Colors.white10,
                ),
                const SizedBox(height: 5),
                Text(
                  "LV. $level  (XP: $totalXp / 100)",
                  style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey),
                ),
              ],
            ),
          ),"""
    new_header = """          // --- 2. 右側：冒險者資訊 ---
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
          ),"""
    content = content.replace(old_header, new_header)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
