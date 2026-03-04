import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove fontFamily: 'Cubic11' which would break longevity mode's standard font Look 
#    Actually, we'll let ThemeData handle the Cubic11 font for RPG mode.
content = re.sub(r"fontFamily:\s*'Cubic11',\s*", "", content)
content = re.sub(r",\s*fontFamily:\s*'Cubic11'", "", content)

# 2. Add Theme definitions
theme_defs = """
// --- 全域主題狀態 ---
final ValueNotifier<bool> isRpgMode = ValueNotifier(false); // 預設為長壽模式

ThemeData _buildLongevityTheme() {
  return ThemeData.light().copyWith(
    primaryColor: const Color(0xFF13503B), // 深綠色
    scaffoldBackgroundColor: const Color(0xFFFAFAFA), // 灰白背景
    cardColor: Colors.white,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: const Color(0xFF112A22),
      displayColor: const Color(0xFF1A8F5A),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAFAFA),
      foregroundColor: Color(0xFF13503B),
      elevation: 0,
    ),
  );
}

ThemeData _buildRpgTheme() {
  return ThemeData.dark().copyWith(
    primaryColor: const Color(0xFF00FF41), // 傳說級黑客綠
    scaffoldBackgroundColor: Colors.black,
    cardColor: const Color(0xFF1A1A1A),
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Cubic11',
      bodyColor: Colors.white,
      displayColor: const Color(0xFF00FF41),
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
              color: isRpg ? Colors.black : const Color(0xFFE0E0E0), // 背景色變換
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
}
"""

content = re.sub(
    r"class FitnessRPGApp extends StatelessWidget \{.*?\n\}\n",
    theme_defs,
    content,
    flags=re.DOTALL
)

# 3. Add onLongPress for the avatar
avatar_tap_pattern = r"""(return GestureDetector\(\s*onTap:\s*\(\)\s*\{\s*showDialog\(\s*context:\s*context,\s*builder:\s*\(context\)\s*=>\s*const\s*SkinSelectionModal\(\),\s*\);\s*\},\s*)child: Container\("""
avatar_tap_repl = r"""\1onLongPress: () {
                isRpgMode.value = !isRpgMode.value;
                HapticFeedback.heavyImpact();
              },
              child: Container("""
content = re.sub(avatar_tap_pattern, avatar_tap_repl, content)

# Fix boundary for active header
content = content.replace("border: Border.all(color: const Color(0xFF00FF41), width: 3),", "border: Border.all(color: Theme.of(context).primaryColor, width: 3),")

# Scaffold background fallback fix
content = content.replace("backgroundColor: Colors.black,", "backgroundColor: Theme.of(context).scaffoldBackgroundColor,")


with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
