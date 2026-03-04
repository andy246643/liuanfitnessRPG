"""
apply_all_features.py
Applies all 4 feature phases to fitness_rpg_app/lib/main.dart:
  Phase 1: Dual theme (LongevityColors + AppThemeMode, top-level ThemeData switch)
  Phase 2: Easter egg 5-tap toggle on avatar
  Phase 3: Achievement chart upgrade (<=10 fixed axis blank / >10 horizontal scroll)
  Phase 4: Left-swipe delete on future plans tab
"""

import re

PATH = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 helpers
# ─────────────────────────────────────────────────────────────────────────────

OLD_FITNESSRPGAPP = """\
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
}"""

NEW_FITNESSRPGAPP = """\
// ── Theme system ───────────────────────────────────────────────────────────
enum AppThemeMode { longevity, rpg }

/// Global notifier – longevity is the default (clean white UI)
final appThemeMode = ValueNotifier<AppThemeMode>(AppThemeMode.longevity);

/// Longevity palette
class LongevityColors {
  static const Color primary    = Color(0xFF2E7D5E);
  static const Color background = Color(0xFFF8F8F4);
  static const Color accent     = Color(0xFF2E7D5E);
  static const Color onPrimary  = Color(0xFFFFFFFF);
  static const Color textMain   = Color(0xFF1A1A1A);
  static const Color textSub    = Color(0xFF666666);
  static const Color border     = Color(0xFFE0E0D1);
  static const Color cardBg     = Color(0xFFFFFFFF);
  static const Color chipBg     = Color(0xFFE8F5EF);
}
// ───────────────────────────────────────────────────────────────────────────

class FitnessRPGApp extends StatelessWidget {
  const FitnessRPGApp({super.key});

  static ThemeData _longevityTheme() {
    return ThemeData.light().copyWith(
      primaryColor: LongevityColors.primary,
      scaffoldBackgroundColor: LongevityColors.background,
      colorScheme: ColorScheme.light(
        primary: LongevityColors.primary,
        secondary: LongevityColors.accent,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: LongevityColors.textMain,
        displayColor: LongevityColors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: LongevityColors.textSub),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: LongevityColors.border)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: LongevityColors.primary, width: 2)),
        prefixIconColor: LongevityColors.textSub,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LongevityColors.primary,
          foregroundColor: LongevityColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  static ThemeData _rpgTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF00FF41),
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00FF41),
        secondary: Color(0xFF00FF41),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Cubic11',
        bodyColor: Colors.white,
        displayColor: const Color(0xFF00FF41),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        final theme = mode == AppThemeMode.rpg ? _rpgTheme() : _longevityTheme();
        return MaterialApp(
          theme: theme,
          builder: (context, child) {
            final bg = mode == AppThemeMode.rpg ? Colors.black : LongevityColors.background;
            return Container(
              color: bg,
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: child,
              ),
            );
          },
          home: const WorkoutManager(),
        );
      },
    );
  }
}"""

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2: Easter egg in _buildCharHeader – replace the old avatar tap handler
# ─────────────────────────────────────────────────────────────────────────────

# We need to:
# 1. Add _secretTapCount state variable
# 2. Add _handleSecretTap() method  
# 3. Replace the skin onTap with _handleSecretTap
# 4. Update icon/text colors to be theme-aware

OLD_CHAR_HEADER = """\
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
  }"""

NEW_CHAR_HEADER = """\
  // ── 彩蛋：連按頭像 5 次切換主題 ──
  int _secretTapCount = 0;
  void _handleSecretTap() {
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      final next = appThemeMode.value == AppThemeMode.rpg
          ? AppThemeMode.longevity
          : AppThemeMode.rpg;
      appThemeMode.value = next;
      final label = next == AppThemeMode.rpg ? '⚔️ RPG 模式' : '🌿 長壽模式';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切換至 $label', style: const TextStyle(fontFamily: 'Cubic11')),
          backgroundColor: next == AppThemeMode.rpg ? const Color(0xFF00FF41).withOpacity(0.85) : LongevityColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 頂部等級條
  Widget _buildCharHeader() {
    final isRpg = appThemeMode.value == AppThemeMode.rpg;
    final primaryClr = Theme.of(context).primaryColor;
    final textClr = isRpg ? Colors.white : LongevityColors.textMain;
    final subClr  = isRpg ? Colors.white70 : LongevityColors.textSub;
    final chipBg  = isRpg ? Colors.white.withOpacity(0.1) : LongevityColors.chipBg;
    final borderClr = primaryClr;
    final namePrefix = isRpg ? "⚔️ 冒險者：" : "👤 ";

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // --- 1. 左側：頭像（彩蛋：連按 5 次切換主題）---
          ValueListenableBuilder<Skin>(
            valueListenable: currentSkin,
            builder: (context, skin, child) {
              return GestureDetector(
                onTap: _handleSecretTap,
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SkinSelectionModal(),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: borderClr, width: 3),
                    shape: BoxShape.circle,
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
          // --- 2. 右側：冒險者資訊 ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "$namePrefix$currentUserName",
                        style: TextStyle(
                          fontFamily: isRpg ? 'Cubic11' : null,
                          color: primaryClr,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.manage_accounts, color: subClr),
                      onPressed: _showProfileDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderClr),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, color: subClr, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "總訓練量: ${totalVolume.toStringAsFixed(0)} kg",
                        style: TextStyle(
                          fontFamily: isRpg ? 'Cubic11' : null,
                          color: textClr,
                          fontSize: 16,
                        ),
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
  }"""

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3: Upgrade _buildExerciseStatsTab with ≤10 fixed / >10 scrollable chart
# ─────────────────────────────────────────────────────────────────────────────

OLD_EXERCISE_STATS_CONTENT = """\
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
                  ),"""

NEW_EXERCISE_STATS_CONTENT = """\
               const SizedBox(height: 16),
               if (spots.isEmpty)
                  const Center(child: Text("此項目無有效數據", style: TextStyle(fontFamily: 'Cubic11', color: Colors.grey)))
               else ...[
                  // >10 items hint
                  if (chartData.length > 10)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swipe, size: 14, color: Colors.white54),
                          SizedBox(width: 4),
                          Text("橫向滑動或縮放查看全部", style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Cubic11')),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Builder(builder: (context) {
                      const int windowSize = 10;
                      final bool needsScroll = chartData.length > windowSize;
                      // For <=10: pad to 10 slots so right side shows blank
                      final double maxX = needsScroll
                          ? spots.length.toDouble() - 1
                          : max(windowSize.toDouble() - 1, 1);

                      Widget chartWidget = LineChart(
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
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 20,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  if (idx < 0 || idx >= chartData.length) return const SizedBox.shrink();
                                  final raw = chartData[idx]['created_at'] as String?;
                                  if (raw == null || raw.length < 10) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(raw.substring(5, 10), style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                  );
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
                              color: const Color(0xFF00FF41),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF00FF41).withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (needsScroll) {
                        // >10: make chart wider and wrap in scroll+zoom
                        final double chartWidth = spots.length * 40.0;
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
                    }),
                  ),
               ],"""

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4: Left-swipe delete in _buildFuturePlansTab
# ─────────────────────────────────────────────────────────────────────────────

OLD_FUTURE_PLANS_TAB = """\
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
  }"""

NEW_FUTURE_PLANS_TAB = """\
  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    try {
      await supabase.from('workout_plans').delete().eq('id', plan['id']);
      setState(() => allPlans.removeWhere((p) => p['id'] == plan['id']));
    } catch (e) {
      debugPrint('Delete plan error: $e');
    }
  }

  Widget _buildFuturePlansTab() {
    final isRpg = appThemeMode.value == AppThemeMode.rpg;
    final primaryClr = Theme.of(context).primaryColor;
    final cardClr = isRpg ? Colors.white10 : LongevityColors.cardBg;
    final textClr = isRpg ? Colors.white : LongevityColors.textMain;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "📜 冒險者公會佈告欄 (未完成)",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isRpg ? 'Cubic11' : null,
            color: isRpg ? Colors.grey : LongevityColors.textSub,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (allPlans.isEmpty)
          Text(
            "目前沒有任何分配的課表",
            textAlign: TextAlign.center,
            style: TextStyle(color: isRpg ? Colors.white54 : LongevityColors.textSub, fontFamily: isRpg ? 'Cubic11' : null),
          ),
        ...allPlans.map((plan) {
          final planId = plan['id'].toString();
          return Dismissible(
            key: Key(planId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: isRpg ? Colors.grey.shade900 : Colors.white,
                  title: Text("刪除課表", style: TextStyle(fontFamily: isRpg ? 'Cubic11' : null, color: textClr)),
                  content: Text("確定要刪除「${plan['plan_name'] ?? '課表'}」？", style: TextStyle(color: textClr)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("刪除", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ) ?? false;
            },
            onDismissed: (_) {
              _deletePlan(plan);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("已刪除「${plan['plan_name'] ?? '課表'}」", style: TextStyle(fontFamily: isRpg ? 'Cubic11' : null)),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Card(
              color: cardClr,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(plan['plan_name'] ?? '未命名課表', style: TextStyle(fontFamily: isRpg ? 'Cubic11' : null, color: textClr)),
                trailing: Icon(Icons.play_arrow, color: primaryClr),
                onTap: () => _startWorkout(plan),
              ),
            ),
          );
        }),
      ],
    );
  }"""


def main():
    with open(PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    issues = []

    # Phase 1: Replace FitnessRPGApp
    if OLD_FITNESSRPGAPP in content:
        content = content.replace(OLD_FITNESSRPGAPP, NEW_FITNESSRPGAPP, 1)
        print("✅ Phase 1: Dual theme applied")
    else:
        issues.append("Phase 1: FitnessRPGApp pattern not found")

    # Phase 2: Replace _buildCharHeader
    if OLD_CHAR_HEADER in content:
        content = content.replace(OLD_CHAR_HEADER, NEW_CHAR_HEADER, 1)
        print("✅ Phase 2: Easter egg toggle applied")
    else:
        issues.append("Phase 2: _buildCharHeader pattern not found")

    # Phase 3: Upgrade chart in _buildExerciseStatsTab
    if OLD_EXERCISE_STATS_CONTENT in content:
        content = content.replace(OLD_EXERCISE_STATS_CONTENT, NEW_EXERCISE_STATS_CONTENT, 1)
        print("✅ Phase 3: Chart upgrade applied")
    else:
        issues.append("Phase 3: exercise stats chart pattern not found")

    # Phase 4: Replace _buildFuturePlansTab with swipe-delete
    if OLD_FUTURE_PLANS_TAB in content:
        content = content.replace(OLD_FUTURE_PLANS_TAB, NEW_FUTURE_PLANS_TAB, 1)
        print("✅ Phase 4: Left-swipe delete applied")
    else:
        issues.append("Phase 4: _buildFuturePlansTab pattern not found")

    if issues:
        print("\n❌ Issues:")
        for issue in issues:
            print(" -", issue)
        print("\nFile NOT written due to issues.")
        return

    # Verify balance
    opens_p = content.count('(')
    closes_p = content.count(')')
    opens_b = content.count('{')
    closes_b = content.count('}')
    print(f"\nBalance check: parens {opens_p}/{closes_p} (diff={opens_p-closes_p}), braces {opens_b}/{closes_b} (diff={opens_b-closes_b})")

    with open(PATH, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ File written successfully.")


if __name__ == '__main__':
    main()
