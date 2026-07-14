import re
import os

with open('analyze_out2.txt', 'r', encoding='utf-16le', errors='ignore') as f:
    lines = f.readlines()

files_with_prints = set()
files_with_opacity = set()
files_with_value = set()

for line in lines:
    if '-' in line and ':' in line:
        parts = line.strip().split(' - ')
        if len(parts) >= 3:
            file_path = parts[1].split(':')[0].strip()
            error_type = parts[-1]
            if error_type == 'avoid_print':
                files_with_prints.add(file_path)
            elif error_type == 'deprecated_member_use':
                if 'withOpacity' in parts[2]:
                    files_with_opacity.add(file_path)
                elif 'value' in parts[2] and 'toARGB32' in parts[2]:
                    files_with_value.add(file_path)

for file_path in files_with_prints:
    if not os.path.exists(file_path):
        continue
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = re.sub(r'\bprint\(', 'debugPrint(', content)
    
    if new_content != content:
        if 'package:flutter/foundation.dart' not in new_content:
            new_content = "import 'package:flutter/foundation.dart';\n" + new_content
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed avoid_print in {file_path}")

for file_path in files_with_opacity:
    if not os.path.exists(file_path):
        continue
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed withOpacity in {file_path}")

for file_path in files_with_value:
    if not os.path.exists(file_path):
        continue
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = re.sub(r'\.value\b', '.toARGB32()', content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed value in {file_path}")
