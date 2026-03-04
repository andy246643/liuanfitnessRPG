import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Colors
text = text.replace('Color get txtCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF112A22);',
                    'Color get txtCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF4A5553);')
text = text.replace('Color get dimCol =>\n    isRpgMode.value ? const Color(0xFF4AF626).withOpacity(0.5) : const Color(0xFF112A22).withOpacity(0.5);',
                    'Color get dimCol =>\n    isRpgMode.value ? const Color(0xFF4AF626).withOpacity(0.5) : const Color(0xFF9EACAA);')
text = text.replace('Color get bgCol => isRpgMode.value ? Colors.black : const Color(0xFFFAFAFA);',
                    'Color get bgCol => isRpgMode.value ? Colors.black : const Color(0xFFF4F6F5);')
text = text.replace('Color get cardBgCol => isRpgMode.value ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA);',
                    'Color get cardBgCol => isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white;')
text = text.replace('Color get pCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF1A8F5A);',
                    'Color get pCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF6B9080);')

text = text.replace('primaryColor: const Color(0xFF13503B), // 深綠色',
                    'primaryColor: const Color(0xFF6B9080), // 溫和綠')
text = text.replace('scaffoldBackgroundColor: const Color(0xFFFAFAFA), // 灰白背景',
                    'scaffoldBackgroundColor: const Color(0xFFF4F6F5), // 溫和灰底')
text = text.replace('backgroundColor: Color(0xFFFAFAFA),',
                    'backgroundColor: Color(0xFFF4F6F5),')
text = text.replace('foregroundColor: Color(0xFF13503B),',
                    'foregroundColor: Color(0xFF6B9080),')
text = text.replace('bodyColor: const Color(0xFF112A22),',
                    'bodyColor: const Color(0xFF4A5553),')
text = text.replace('displayColor: const Color(0xFF1A8F5A),',
                    'displayColor: const Color(0xFF6B9080),')

# 2. Add properties
text = text.replace('// 預設為長壽模式', "String? get fFam => isRpgMode.value ? 'Cubic11' : null;\n\n// 預設為長壽模式")

# 3. Add fFam to TextStyle(
# We can just split by 'TextStyle(' and if the next segment doesn't start with 'fontFamily' and doesn't contain 'fontFamily' before the next ')', we inject.
parts = text.split('TextStyle(')
for i in range(1, len(parts)):
    # if it doesn't already have fFam or Cubic11 inside the block
    if not parts[i].lstrip().startswith('fontFamily'):
        # Check if it has fontFamily before closing paren
        # Simple heuristic: if 'fontFamily' is in the first 100 chars
        head = parts[i][:150]
        if 'fontFamily' not in head:
            parts[i] = 'fontFamily: fFam, ' + parts[i]

text = 'TextStyle('.join(parts)

# 4. Text modifications
text = text.replace('"⚔️ 冒險者：$currentUserName"', '(isRpgMode.value ? "⚔️ 冒險者：$currentUserName" : "👤 名字：$currentUserName")')
text = text.replace('"🔑 冒險者登入"', '(isRpgMode.value ? "🔑 冒險者登入" : "🔑 使用者登入")')
text = text.replace('"冒險者名稱 (例如：Test Trainee)"', '(isRpgMode.value ? "冒險者名稱 (例如：Test Trainee)" : "使用者名稱")')

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Replacement complete")
