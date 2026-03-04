import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Restore critical consts that were accidentally removed
text = text.replace('final supabaseUrl = String.fromEnvironment', 'const supabaseUrl = String.fromEnvironment')
text = text.replace('final supabaseAnonKey = String.fromEnvironment', 'const supabaseAnonKey = String.fromEnvironment')
text = text.replace('runApp( FitnessRPGApp());', 'runApp(const FitnessRPGApp());')
text = text.replace(' FitnessRPGApp({super.key});', ' const FitnessRPGApp({super.key});')
text = text.replace(' WorkoutManager({super.key});', ' const WorkoutManager({super.key});')

# 2. Add back 'const' to common Flutter widgets that don't use dynamic properties
# (This is harder to do safely without a parser, but let's at least fix the obvious ones)
text = text.replace('EdgeInsets.all', 'const EdgeInsets.all')
text = text.replace('EdgeInsets.symmetric', 'const EdgeInsets.symmetric')
text = text.replace('SizedBox(height', 'const SizedBox(height')
text = text.replace('SizedBox(width', 'const SizedBox(width')
text = text.replace('Icon(Icons.', 'const Icon(Icons.')

# 3. Fix the conditional header rendering to avoid nested identical ternary
text = text.replace('(isRpgMode.value ? (isRpgMode.value ? "⚔️ 冒險者：$currentUserName" : "👤 名字：$currentUserName") : "👤 名字：$currentUserName")', 
                    '(isRpgMode.value ? "⚔️ 冒險者：$currentUserName" : "👤 名字：$currentUserName")')

# 4. Ensure Color(0xFF...) has const if it's not dynamic
text = re.sub(r'(?<!const )Color\(0xFF[0-9A-F]{6,8}\)', r'const Color(\g<0>)', text)
# Wait, that regex might duplicate if const is already there. Better:
text = re.sub(r'Color\(0xFF[0-9A-F]{6,8}\)', lambda m: 'const ' + m.group(0) if 'const' not in text[max(0, text.find(m.group(0))-7):text.find(m.group(0))] else m.group(0), text)

# Actually, let's just use a simpler replacement for Colors
text = text.replace(' Color(0xFF', ' const Color(0xFF')

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Fix applied.")
