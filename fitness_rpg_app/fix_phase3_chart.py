"""
fix_phase3_chart.py — upgrades _buildExerciseStatsTab chart using line-number approach
"""

PATH = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'

def main():
    with open(PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.splitlines()

    # Find the chart block: starts with 'const SizedBox(height: 40),' around line 983
    # and ends at the closing '),' of the Expanded widget around line 1048
    start_idx = None
    end_idx = None
    for i, line in enumerate(lines):
        if i > 900 and i < 1100:
            if 'SizedBox(height: 40)' in line and start_idx is None:
                start_idx = i
            if start_idx is not None and i > start_idx:
                # End marker: line with '              ),' that closes the Expanded (starts Expanded around line 987)
                # We look for '              ),' followed by SizedBox(height: 20)
                if 'SizedBox(height: 20)' in lines[i]:
                    end_idx = i
                    break

    if start_idx is None or end_idx is None:
        print(f'Could not find chart block. start={start_idx} end={end_idx}')
        return

    print(f'Chart block: lines {start_idx+1} to {end_idx} (0-indexed {start_idx} to {end_idx-1})')
    print('Old starts with:', repr(lines[start_idx][:60]))
    print('Old ends with:', repr(lines[end_idx-1][:60]))

    old_block = '\n'.join(lines[start_idx:end_idx])

    new_block = (
        "              const SizedBox(height: 16),\n"
        "              if (spots.isEmpty)\n"
        "                 const Center(child: Text(\"此項目無有效數據\", style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey)))\n"
        "              else ...[\n"
        "                 if (chartData.length > 10)\n"
        "                   const Padding(\n"
        "                     padding: EdgeInsets.only(bottom: 6),\n"
        "                     child: Row(\n"
        "                       mainAxisAlignment: MainAxisAlignment.center,\n"
        "                       children: [\n"
        "                         Icon(Icons.swipe, size: 14, color: Colors.white54),\n"
        "                         SizedBox(width: 4),\n"
        "                         Text(\"橫向滑動查看全部\", style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Cubic11')),\n"
        "                       ],\n"
        "                     ),\n"
        "                   ),\n"
        "                 Expanded(\n"
        "                    child: Builder(builder: (context) {\n"
        "                      const int windowSize = 10;\n"
        "                      final bool needsScroll = chartData.length > windowSize;\n"
        "                      final double maxX = needsScroll\n"
        "                          ? spots.length.toDouble() - 1\n"
        "                          : max(windowSize.toDouble() - 1, 1);\n"
        "\n"
        "                      Widget chartWidget = LineChart(\n"
        "                        LineChartData(\n"
        "                          gridData: FlGridData(\n"
        "                            show: true,\n"
        "                            drawVerticalLine: false,\n"
        "                            getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),\n"
        "                          ),\n"
        "                          titlesData: FlTitlesData(\n"
        "                            leftTitles: AxisTitles(\n"
        "                              sideTitles: SideTitles(\n"
        "                                showTitles: true,\n"
        "                                reservedSize: 40,\n"
        "                                getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),\n"
        "                              ),\n"
        "                            ),\n"
        "                            bottomTitles: AxisTitles(\n"
        "                              sideTitles: SideTitles(\n"
        "                                showTitles: true,\n"
        "                                reservedSize: 22,\n"
        "                                interval: 1,\n"
        "                                getTitlesWidget: (value, meta) {\n"
        "                                  int idx = value.toInt();\n"
        "                                  if (idx >= 0 && idx < chartData.length) {\n"
        "                                    final rawDate = chartData[idx]['created_at'] as String?;\n"
        "                                    if (rawDate != null && rawDate.length >= 10) {\n"
        "                                      return Padding(\n"
        "                                        padding: const EdgeInsets.only(top: 5.0),\n"
        "                                        child: Text(rawDate.substring(5,10).replaceFirst('-','/'), style: const TextStyle(color: Colors.grey, fontSize: 8, fontFamily: 'Cubic11')),\n"
        "                                      );\n"
        "                                    }\n"
        "                                  }\n"
        "                                  return const SizedBox.shrink();\n"
        "                                },\n"
        "                              ),\n"
        "                            ),\n"
        "                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),\n"
        "                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),\n"
        "                          ),\n"
        "                          borderData: FlBorderData(show: false),\n"
        "                          minX: 0,\n"
        "                          maxX: maxX,\n"
        "                          minY: 0,\n"
        "                          maxY: maxVol * 1.2,\n"
        "                          lineBarsData: [\n"
        "                            LineChartBarData(\n"
        "                              spots: spots,\n"
        "                              isCurved: true,\n"
        "                              color: const Color(0xFF00FF41),\n"
        "                              barWidth: 3,\n"
        "                              isStrokeCapRound: true,\n"
        "                              dotData: const FlDotData(show: true),\n"
        "                              belowBarData: BarAreaData(\n"
        "                                show: true,\n"
        "                                color: const Color(0xFF00FF41).withOpacity(0.2),\n"
        "                              ),\n"
        "                            ),\n"
        "                          ],\n"
        "                        ),\n"
        "                      );\n"
        "\n"
        "                      if (needsScroll) {\n"
        "                        final double chartWidth = spots.length * 44.0;\n"
        "                        return InteractiveViewer(\n"
        "                          constrained: false,\n"
        "                          scaleEnabled: true,\n"
        "                          child: SingleChildScrollView(\n"
        "                            scrollDirection: Axis.horizontal,\n"
        "                            child: SizedBox(width: chartWidth, child: chartWidget),\n"
        "                          ),\n"
        "                        );\n"
        "                      }\n"
        "                      return chartWidget;\n"
        "                    }),\n"
        "                 ),\n"
        "              ],"
    )

    if old_block not in content:
        print('ERROR: old_block not found in content exactly — check line endings')
        return

    new_content = content.replace(old_block, new_block, 1)
    p_diff = new_content.count('(') - new_content.count(')')
    b_diff = new_content.count('{') - new_content.count('}')
    print(f'Balance: parens diff={p_diff}, braces diff={b_diff}')

    if p_diff != 0 or b_diff != 0:
        print('ERROR: imbalanced — not writing')
        return

    with open(PATH, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Phase 3 chart upgrade written successfully!')


if __name__ == '__main__':
    main()
