import os, glob, re

future_dir = 'lib/future'
all_files = glob.glob(os.path.join(future_dir, '**/*.dart'), recursive=True)

import_pattern = re.compile(r"(import|export)\s+['\"](.*?)['\"]")

def resolve_import(file_path, relative_import):
    if not relative_import.startswith('.'):
        return relative_import
    # Get the directory of the file relative to the project root
    file_dir = os.path.dirname(file_path)
    # The relative import is relative to file_dir
    target_path = os.path.normpath(os.path.join(file_dir, relative_import))
    # Change backslashes to forward slashes
    target_path = target_path.replace('\\', '/')
    # Replace 'lib/' with 'package:vinci_board/'
    if target_path.startswith('lib/'):
        return target_path.replace('lib/', 'package:vinci_board/', 1)
    return relative_import

for fpath in all_files:
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        new_content = content
        for match in import_pattern.finditer(content):
            prefix = match.group(1)
            rel_import = match.group(2)
            if rel_import.startswith('.'):
                resolved = resolve_import(fpath, rel_import)
                if resolved != rel_import:
                    old_line = f"{prefix} '{rel_import}'"
                    new_line = f"{prefix} '{resolved}'"
                    # Also try double quotes
                    old_line_2 = f"{prefix} \"{rel_import}\""
                    new_line_2 = f"{prefix} \"{resolved}\""
                    new_content = new_content.replace(old_line, new_line).replace(old_line_2, new_line_2)
        
        if new_content != content:
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(new_content)
    except Exception as e:
        print(f"Error processing {fpath}: {e}")
