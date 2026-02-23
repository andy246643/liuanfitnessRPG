import re

def main():
    path = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add imports
    if "import 'package:fl_chart/fl_chart.dart';" not in content:
        content = content.replace("import 'package:flutter_application_1/models/skin.dart';", "import 'package:flutter_application_1/models/skin.dart';\nimport 'package:fl_chart/fl_chart.dart';\nimport 'dart:math';")

    # 2. Add State variables
    state_vars = """  // 4. 歷史與成就相關
  List<Map<String, dynamic>> historicalSessions = [];
  Map<String, List<Map<String, dynamic>>> achievementStats = {};
  String? selectedAchievementExercise;"""
    
    if "List<Map<String, dynamic>> historicalSessions" not in content:
        content = content.replace(
            '  String lastCompletionRate = "0%";',
            '  String lastCompletionRate = "0%";\n\n' + state_vars
        )

    # 3. Add fetch logic inside _fetchPlans
    fetch_plans_old = """  Future<void> _fetchPlans() async {
    if (currentUserId.isEmpty) return;

    final response = await supabase
        .from('workout_plans')
        .select('id, plan_name')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);
    setState(() {
      allPlans = List<Map<String, dynamic>>.from(response);
    });
  }"""
    
    fetch_plans_new = """  Future<void> _fetchPlans() async {
    if (currentUserId.isEmpty) return;

    // 1. 抓取未來課表 (尚未完成的計畫，這邊先簡單列出所有)
    final response = await supabase
        .from('workout_plans')
        .select('id, plan_name')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);
        
    // 2. 抓取歷史課表 (已完成的紀錄)
    final logsResponse = await supabase
        .from('workout_logs')
        .select('id, plan_name, created_at, exercise_name, volume, weight')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);
        
    final logs = List<Map<String, dynamic>>.from(logsResponse);
    
    // 將歷史紀錄分組 (依據日期與計畫名稱)
    final Map<String, Map<String, dynamic>> sessionsMap = {};
    final Map<String, List<Map<String, dynamic>>> statsMap = {};
    
    for (var log in logs) {
      // 處理 session 群組
      final dateStr = (log['created_at'] as String).substring(0, 10);
      final planName = log['plan_name'] ?? '未知課表';
      final exName = log['exercise_name'] ?? '未知名稱';
      final key = '${dateStr}_$planName';
      
      if (!sessionsMap.containsKey(key)) {
        sessionsMap[key] = {
          'date': dateStr,
          'plan_name': planName,
        };
      }
      
      // 處理成就統計 (排除總結)
      if (!exName.contains('🏆 副本總結')) {
         if (!statsMap.containsKey(exName)) {
            statsMap[exName] = [];
         }
         statsMap[exName]!.add(log);
      }
    }
    
    // 排序成就資料 (由舊到新)
    for (var key in statsMap.keys) {
       statsMap[key]!.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    }
    
    final sessionsList = sessionsMap.values.toList();
    sessionsList.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    setState(() {
      allPlans = List<Map<String, dynamic>>.from(response);
      historicalSessions = sessionsList;
      achievementStats = statsMap;
      if (statsMap.isNotEmpty && selectedAchievementExercise == null) {
         selectedAchievementExercise = statsMap.keys.first;
      }
    });
  }"""
    
    content = content.replace(fetch_plans_old, fetch_plans_new)

    # 4. Replace _buildLobbyMode entirely
    
    lobby_mode_start = content.find('  // 大廳選計畫\n  Widget _buildLobbyMode() {')
    lobby_mode_end = content.find('  // 副本任務佈告欄\n  Widget _buildQuestLog(double finalRate) {')
    
    old_lobby_mode = content[lobby_mode_start:lobby_mode_end]

    new_lobby_mode = """  // 大廳選計畫 (改為 Tabbed View)
  Widget _buildLobbyMode() {
    if (currentUserId.isEmpty) {
       return _buildLoginForm();
    }

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
            (session) => Card(
              color: Colors.white10,
              child: ListTile(
                leading: const Icon(Icons.history_edu, color: Colors.grey),
                title: Text(session['plan_name'], style: const TextStyle(fontFamily: 'Cubic11',color: Colors.white)),
                subtitle: Text(session['date'], style: const TextStyle(fontFamily: 'Cubic11', color: Colors.grey, fontSize: 12)),
              ),
            ),
          ),
        ],
     );
  }

  Widget _buildAchievementsTab() {
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
        double vol = (chartData[i]['volume'] as num?)?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), vol));
        if (vol > maxVol) maxVol = vol;
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
                             bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                "說明：縱軸為該動作的總容量 (Volume = Sets x Reps x Weight)\n橫軸為歷史訓練次數 (由左至右為舊到新)",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey.shade500, fontSize: 10),
              ),
           ],
        ),
     );
  }

"""
    
    content = content.replace(old_lobby_mode, new_lobby_mode)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
