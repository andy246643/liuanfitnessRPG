import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add fFam at the top near state vars
fFam_declaration = "String? get fFam => isRpgMode.value ? 'Cubic11' : null;\n\n// 預設為長壽模式"
content = content.replace('// 預設為長壽模式', fFam_declaration)

# 2. Update Colors for longevity mode (softer green and gray)
content = content.replace(
    'Color get txtCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF112A22);',
    'Color get txtCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF4A5553);'
)
content = content.replace(
    'Color get dimCol =>\n    isRpgMode.value ? const Color(0xFF4AF626).withOpacity(0.5) : const Color(0xFF112A22).withOpacity(0.5);',
    'Color get dimCol =>\n    isRpgMode.value ? const Color(0xFF4AF626).withOpacity(0.5) : const Color(0xFF9EACAA);'
)
content = content.replace(
    'Color get bgCol => isRpgMode.value ? Colors.black : const Color(0xFFFAFAFA);',
    'Color get bgCol => isRpgMode.value ? Colors.black : const Color(0xFFF4F6F5);'
)
content = content.replace(
    'Color get cardBgCol => isRpgMode.value ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA);',
    'Color get cardBgCol => isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white;'
)
content = content.replace(
    'Color get pCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF1A8F5A);',
    'Color get pCol => isRpgMode.value ? const Color(0xFF4AF626) : const Color(0xFF6B9080);'
)

# Replace longevity theme hardcoded colors
content = content.replace(
    'primaryColor: const Color(0xFF13503B), // 深綠色',
    'primaryColor: const Color(0xFF6B9080), // 溫和綠'
)
content = content.replace(
    'scaffoldBackgroundColor: const Color(0xFFFAFAFA), // 灰白背景',
    'scaffoldBackgroundColor: const Color(0xFFF4F6F5), // 溫和灰底'
)
content = content.replace(
    'backgroundColor: Color(0xFFFAFAFA),',
    'backgroundColor: Color(0xFFF4F6F5),'
)
content = content.replace(
    'foregroundColor: Color(0xFF13503B),',
    'foregroundColor: Color(0xFF6B9080),'
)
content = content.replace(
    'bodyColor: const Color(0xFF112A22),',
    'bodyColor: const Color(0xFF4A5553),'
)
content = content.replace(
    'displayColor: const Color(0xFF1A8F5A),',
    'displayColor: const Color(0xFF6B9080),'
)

# 3. Add fontFamily: fFam to all TestStyles except those that already have it
content = re.sub(r'TextStyle\(\s*([^f][^o][^n][^t][^F][^a][^m][^i][^l][^y].*?)\)', r'TextStyle(fontFamily: fFam, \1)', content)
# Ensure we don't accidentally match empty TextStyle()
content = re.sub(r'TextStyle\(\s*\)', r'TextStyle(fontFamily: fFam)', content)

# But wait, python regex negative lookahead is better:
# actually I will just write a simple logic:
def replace_text_style(match):
    text = match.group(0)
    if \'fontFamily\' not in text:
        return text.replace(\'TextStyle(\', \'TextStyle(fontFamily: fFam, \')
    return text

content = re.sub(r\'TextStyle\([^)]*\)\', replace_text_style, content)

# 4. Change "冒險者" to "名字" in the Header conditionally
# Previous: Text(\n  "⚔️ 冒險者：$currentUserName"
header_search = \'"⚔️ 冒險者：$currentUserName"\'
header_replace = \'(isRpgMode.value ? "⚔️ 冒險者：$currentUserName" : "👤 名字：$currentUserName")\'
content = content.replace(header_search, header_replace)

# Also login form: Text(\n "🔑 冒險者登入",
content = content.replace(\'"🔑 冒險者登入"\', \'(isRpgMode.value ? "🔑 冒險者登入" : "🔑 使用者登入")\')
content = content.replace(\'"冒險者名稱 (例如：Test Trainee)"\', \'(isRpgMode.value ? "冒險者名稱 (例如：Test Trainee)" : "使用者名稱")\')

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
