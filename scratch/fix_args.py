import os
import re

def fix_args(file_path):
    if not os.path.exists(file_path): return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = content.replace('.scaleByDouble(', '.scale(')
    new_content = new_content.replace('.translateByDouble(', '.translate(')
    
    if new_content != content:
        # Also prepend ignore for file
        if '// ignore_for_file: deprecated_member_use' not in new_content:
            new_content = '// ignore_for_file: deprecated_member_use\n' + new_content
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed args in {file_path}")

fix_args(r'lib\presentation\screens\canvas_screen.dart')
fix_args(r'lib\presentation\screens\canvas\canvas_widget.dart')
fix_args(r'lib\presentation\screens\canvas\animated_stroke_widget.dart')
fix_args(r'lib\core\canvas\canvas_controller.dart')
fix_args(r'lib\core\utils\sketch_templates.dart')
