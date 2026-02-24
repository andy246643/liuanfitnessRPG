import re

def main():
    path = r'c:\dev\liuan_fitness_rpg_flutter\fitness_rpg_app\lib\main.dart'
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    # Find the method code
    pattern = r'(\n+)?\s+Widget _buildBodyStatsTab\(\) \{.*?\n\s{3}\}'
    match = re.search(pattern, text, re.DOTALL)
    
    if match:
        method_code = match.group(0)
        # Remove it from its current wrong location
        text = text.replace(method_code, '', 1)
        
        # Clean up the method code to ensure proper spacing
        method_code = '\n' + method_code.strip() + '\n'
        
        # Find the insertion point before `class SkinSelectionModal`
        # 1440:     );
        # 1441:   }
        # 1442: }
        # 1443: 
        # 1444: class SkinSelectionModal extends StatefulWidget {
        target_pattern = r'    \);\n  \}\n\}\n+class SkinSelectionModal'
        target_match = re.search(target_pattern, text)
        if target_match:
            new_target = '    );\n  }' + method_code + '}\n\nclass SkinSelectionModal'
            text = text.replace(target_match.group(0), new_target)
            
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
            print("Successfully moved _buildBodyStatsTab")
        else:
            print("Target insertion point not found.")
    else:
        print("Method _buildBodyStatsTab not found.")

if __name__ == '__main__':
    main()
