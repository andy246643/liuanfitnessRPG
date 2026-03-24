import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../theme/zen_theme.dart';
import '../services/muscle_group_classifier.dart';

/// 分類卡片式圖表：按肌群分組，展開後顯示動作選擇和折線圖
class StatsView extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> achievementStats;
  final List<Map<String, dynamic>> weightHistory;
  final List<Map<String, dynamic>> bodyFatHistory;

  const StatsView({
    super.key,
    required this.achievementStats,
    required this.weightHistory,
    required this.bodyFatHistory,
  });

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  final Map<String, bool> _expandedGroups = {};
  final Map<String, String?> _selectedExercisePerGroup = {};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: pCol,
            unselectedLabelColor: Colors.grey,
            indicatorColor: pCol,
            labelStyle: TextStyle(fontFamily: fFam, fontSize: 14),
            tabs: const [
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

  // ============================
  // 動作數據 Tab — 分類卡片式
  // ============================
  Widget _buildExerciseStatsTab() {
    if (widget.achievementStats.isEmpty) {
      return Center(
        child: Text("尚未累積足夠的成就數據", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
      );
    }

    final grouped = MuscleGroupClassifier.groupExercises(widget.achievementStats.keys);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              isRpgMode.value ? "📊 戰力成長分析" : "📊 訓練動作數據",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fFam,
                color: txtCol,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final groupEntry = grouped.entries.elementAt(index - 1);
        final groupName = groupEntry.key;
        final exercises = groupEntry.value;
        final isExpanded = _expandedGroups[groupName] ?? false;

        return _buildMuscleGroupCard(groupName, exercises, isExpanded);
      },
    );
  }

  Widget _buildMuscleGroupCard(String groupName, List<String> exercises, bool isExpanded) {
    final iconWidget = MuscleGroupClassifier.buildIcon(groupName, size: 24);
    final progress = _calculateGroupProgress(exercises);
    final selectedExercise = _selectedExercisePerGroup[groupName] ?? exercises.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBgCol,
        borderRadius: BorderRadius.circular(isRpgMode.value ? 4 : 20),
        border: isRpgMode.value ? Border.all(color: pCol, width: 1.5) : null,
        boxShadow: isRpgMode.value
            ? null
            : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // 卡片標頭（點擊展開/收合）
          InkWell(
            onTap: () => setState(() => _expandedGroups[groupName] = !isExpanded),
            borderRadius: BorderRadius.circular(isRpgMode.value ? 4 : 20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: TextStyle(
                            fontFamily: fFam,
                            color: txtCol,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exercises.join('、'),
                          style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 進步指標
                  if (progress != null) _buildProgressBadge(progress),
                  const SizedBox(width: 8),
                  // 動作數量
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pCol.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${exercises.length}',
                      style: TextStyle(fontFamily: fFam, color: pCol, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: dimCol,
                  ),
                ],
              ),
            ),
          ),

          // 展開內容
          if (isExpanded) ...[
            Divider(height: 1, color: dimCol.withAlpha(50)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // 動作選擇 Chips（多於 1 個動作時）
                  if (exercises.length > 1)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: exercises.map((ex) {
                          final isSelected = ex == selectedExercise;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                ex,
                                style: TextStyle(
                                  fontFamily: fFam,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : txtCol,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: pCol,
                              backgroundColor: cardBgCol,
                              side: BorderSide(color: isSelected ? pCol : dimCol.withAlpha(80)),
                              onSelected: (_) => setState(() => _selectedExercisePerGroup[groupName] = ex),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (exercises.length > 1) const SizedBox(height: 12),

                  // 折線圖
                  _buildExerciseChart(selectedExercise),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseChart(String exerciseName) {
    final chartData = widget.achievementStats[exerciseName] ?? [];
    if (chartData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text("此項目無有效數據", style: TextStyle(fontFamily: fFam, color: Colors.grey)),
      );
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

    final int windowSize = 10;
    final bool needsScroll = chartData.length > windowSize;
    final double maxX = needsScroll
        ? spots.length.toDouble() - 1
        : max(windowSize.toDouble() - 1, 1);

    Widget chartWidget = SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: dimCol.withAlpha(60), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: max(1, (spots.length / 6).floor().toDouble()),
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < chartData.length) {
                    final rawDate = chartData[idx]['created_at'] as String?;
                    if (rawDate != null && rawDate.length >= 10) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          rawDate.substring(5, 10).replaceFirst('-', '/'),
                          style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 8),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: pCol.withAlpha(40),
              ),
            ),
          ],
        ),
      ),
    );

    if (needsScroll) {
      final double chartWidth = spots.length * 44.0;
      chartWidget = Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe, size: 12, color: dimCol),
              const SizedBox(width: 4),
              Text("橫向滑動查看全部", style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 180,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: chartWidth, child: chartWidget),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        chartWidget,
        const SizedBox(height: 6),
        Text(
          hasWeight ? "單位：kg（重量）" : "單位：次（次數）",
          style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 10),
        ),
      ],
    );
  }

  // ============================
  // 進步指標
  // ============================
  ({double delta, bool hasWeight})? _calculateGroupProgress(List<String> exercises) {
    // 取該組第一個有數據的動作
    for (final ex in exercises) {
      final data = widget.achievementStats[ex];
      if (data == null || data.length < 2) continue;

      final first = data.first;
      final last = data.last;
      final firstW = (first['weight'] as num?)?.toDouble() ?? 0.0;
      final lastW = (last['weight'] as num?)?.toDouble() ?? 0.0;
      final firstR = (first['reps'] as num?)?.toDouble() ?? 0.0;
      final lastR = (last['reps'] as num?)?.toDouble() ?? 0.0;

      if (firstW > 0 || lastW > 0) {
        return (delta: lastW - firstW, hasWeight: true);
      } else {
        return (delta: lastR - firstR, hasWeight: false);
      }
    }
    return null;
  }

  Widget _buildProgressBadge(({double delta, bool hasWeight}) progress) {
    final delta = progress.delta;
    final unit = progress.hasWeight ? 'kg' : '次';
    final threshold = progress.hasWeight ? 0.5 : 0.5;

    Color color;
    IconData icon;
    String text;

    if (delta > threshold) {
      color = Colors.green;
      icon = Icons.arrow_upward;
      text = '+${delta.toStringAsFixed(progress.hasWeight ? 1 : 0)}$unit';
    } else if (delta < -threshold) {
      color = Colors.red;
      icon = Icons.arrow_downward;
      text = '${delta.toStringAsFixed(progress.hasWeight ? 1 : 0)}$unit';
    } else {
      color = Colors.grey;
      icon = Icons.arrow_forward;
      text = '維持';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontFamily: fFam, color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================
  // 身體變化 Tab（保留原有邏輯）
  // ============================
  Widget _buildBodyStatsTab() {
    if (widget.weightHistory.isEmpty && widget.bodyFatHistory.isEmpty) {
      return Center(
        child: Text(
          "尚未記錄任何身體數據，請點擊上方頭像旁的設定按鍵新增。",
          style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    List<FlSpot> weightSpots = [];
    double maxWeight = 0;
    double minWeight = double.infinity;
    for (int i = 0; i < widget.weightHistory.length; i++) {
      double w = (widget.weightHistory[i]['weight'] as num).toDouble();
      weightSpots.add(FlSpot(i.toDouble(), w));
      if (w > maxWeight) maxWeight = w;
      if (w < minWeight) minWeight = w;
    }
    if (minWeight == double.infinity) minWeight = 0;

    List<FlSpot> fatSpots = [];
    double maxFat = 0;
    double minFat = double.infinity;
    for (int i = 0; i < widget.bodyFatHistory.length; i++) {
      double f = (widget.bodyFatHistory[i]['body_fat'] as num).toDouble();
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
          Text(
            "💪 體重變化與體脂走勢",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (weightSpots.isEmpty && fatSpots.isEmpty)
            Center(child: Text("目前無記錄", style: TextStyle(fontFamily: fFam, color: Colors.grey)))
          else
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: dimCol, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text("數值", style: TextStyle(fontFamily: fFam, color: dimCol, fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (val, meta) =>
                            Text(val.toInt().toString(), style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 10)),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: maxWeight > 0 || maxFat > 0
                      ? max(
                          weightSpots.length > fatSpots.length
                              ? weightSpots.length.toDouble() - 1
                              : fatSpots.length.toDouble() - 1,
                          1.0)
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
                        dotData: const FlDotData(show: true),
                      ),
                    if (fatSpots.isNotEmpty)
                      LineChartBarData(
                        spots: fatSpots,
                        isCurved: true,
                        color: Colors.redAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
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
              Text("體重 (kg)", style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 20),
              Container(width: 12, height: 12, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text("體脂 (%)", style: TextStyle(fontFamily: fFam, color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
