import re

FILE_PATH = r"c:\dev\liuan_fitness_rpg_flutter\coach_dashboard_app\lib\screens\plan_editor_screen.dart"

with open(FILE_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the methods from the top where they were wrongly inserted
pattern_wrong = re.compile(r"  void _addAltSet\(\) \{.*?\n  @override\n", re.DOTALL)
content = pattern_wrong.sub("  @override\n", content)

with open(FILE_PATH, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
