import re

def main():
    path = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    # Remove the first occurrence of `  // 顯示個人資料設定對話框...` entirely if there are two
    pattern = r'  // 顯示個人資料設定對話框\n  void _showProfileDialog\(\) \{.*?\n  // 頂部等級條'
    matches = re.findall(pattern, text, re.DOTALL)
    if len(matches) > 1:
        text = text.replace(matches[0], '  // 頂部等級條', 1)
        
    # Re-apply `_buildBodyStatsTab` at the very end of `_WorkoutManagerState` (before the last closing brace)
    if 'Widget _buildBodyStatsTab' not in text:
        old_end = '} // End of _WorkoutManagerState'
        if old_end not in text:
            old_end = '}\n'
            idx = text.rfind('}')
            if idx != -1:
                body_stats = '''

   Widget _buildBodyStatsTab() {
      if (weightHistory.isEmpty && bodyFatHistory.isEmpty) {
         return const Center(
            child: Text("尚未記錄任何身體數據，請點擊上方頭像旁的設定按鈕新增。", style: TextStyle(fontFamily: \'Cubic11\', color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
         );
      }

      List<FlSpot> weightSpots = [];
      double maxWeight = 0;
      double minWeight = double.infinity;
      for (int i = 0; i < weightHistory.length; i++) {
         double w = (weightHistory[i][\'weight\'] as num).toDouble();
         weightSpots.add(FlSpot(i.toDouble(), w));
         if (w > maxWeight) maxWeight = w;
         if (w < minWeight) minWeight = w;
      }
      if (minWeight == double.infinity) minWeight = 0;

      List<FlSpot> fatSpots = [];
      double maxFat = 0;
      double minFat = double.infinity;
      for (int i = 0; i < bodyFatHistory.length; i++) {
         double f = (bodyFatHistory[i][\'body_fat\'] as num).toDouble();
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
                 style: TextStyle(fontFamily: \'Cubic11\',color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 20),
               if (weightSpots.isEmpty && fatSpots.isEmpty)
                  const Center(child: Text("目前無記錄", style: TextStyle(fontFamily: \'Cubic11\', color: Colors.grey)))
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
                                 axisNameWidget: const Text("數值", style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: \'Cubic11\')),
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
                   const Text("體重 (kg)", style: TextStyle(color: Colors.grey, fontFamily: \'Cubic11\', fontSize: 12)),
                   const SizedBox(width: 20),
                   Container(width: 12, height: 12, color: Colors.redAccent),
                   const SizedBox(width: 8),
                   const Text("體脂 (%)", style: TextStyle(color: Colors.grey, fontFamily: \'Cubic11\', fontSize: 12)),
                 ],
               ),
            ],
         ),
      );
   }
}
'''
                text = text[:idx] + body_stats

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print('Applied python fix.')

if __name__ == '__main__':
    main()
