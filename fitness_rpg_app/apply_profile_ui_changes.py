import re

def main():
    path = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # We need to add `_showProfileDialog` just before `Widget _buildCharHeader()`
    
    dialog_code = """
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

  // 頂部等級條"""
    
    content = content.replace("  // 頂部等級條", dialog_code)
    
    # 2. Modify `_buildAchievementsTab` to have sub-tabs
    
    old_achievements_tab = """  Widget _buildAchievementsTab() {
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
     }).toList();"""
    
    new_achievements_tab = """  Widget _buildAchievementsTab() {
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
     }).toList();"""

    content = content.replace(old_achievements_tab, new_achievements_tab)
    
    # Add body stats tab at the end of _buildExerciseStatsTab
    exercise_tab_end_old = """               Text(
                 "說明：縱軸為該動作的總容量 (Volume = Sets x Reps x Weight)\\n橫軸為歷史訓練次數 (由左至右為舊到新)",
                 textAlign: TextAlign.center,
                 style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey.shade500, fontSize: 10),
               ),
            ],
         ),
      );
   }"""
    exercise_tab_end_new = """               Text(
                 "說明：縱軸為該動作的總容量 (Volume = Sets x Reps x Weight)\\n橫軸為歷史訓練次數 (由左至右為舊到新)",
                 textAlign: TextAlign.center,
                 style: TextStyle(fontFamily: 'Cubic11',color: Colors.grey.shade500, fontSize: 10),
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
                           maxX: max(
                             weightSpots.length > fatSpots.length ? weightSpots.length.toDouble() - 1 : fatSpots.length.toDouble() - 1,
                             1
                           ),
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
   }"""
    content = content.replace(exercise_tab_end_old, exercise_tab_end_new)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
