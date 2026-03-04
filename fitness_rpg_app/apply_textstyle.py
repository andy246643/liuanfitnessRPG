import os

file_path = 'lib/main.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

parts = text.split('TextStyle(')
new_parts = [parts[0]]

for part in parts[1:]:
    # Logic to inject fontFamily: fFam,
    # Find the matching closing paren to be safe, but simple check for fontFamily is usually enough
    # If fontFamily is not in the first 100 characters of this block, inject it
    if 'fontFamily' not in part[:150]:
        if part.strip().startswith(')'):
             new_parts.append('fontFamily: fFam' + part)
        else:
             new_parts.append('fontFamily: fFam, ' + part)
    else:
        new_parts.append(part)

final_text = 'TextStyle('.join(new_parts)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(final_text)

print("Font injection complete.")
