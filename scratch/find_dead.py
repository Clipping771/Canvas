import os, glob, re

lib_dir = 'lib'
all_dart_files = glob.glob(os.path.join(lib_dir, '**/*.dart'), recursive=True)
all_dart_files = [os.path.normpath(f) for f in all_dart_files]

imported_files = set()
import_pattern = re.compile(r"(?:import|export)\s+['\"](.*?)['\"]")

for fpath in all_dart_files:
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        for match in import_pattern.findall(content):
            if match.startswith('package:vinci_board/'):
                rel_path = match.replace('package:vinci_board/', '')
                imported_files.add(os.path.normpath(os.path.join(lib_dir, rel_path)))
            elif match.startswith('package:'):
                continue
            elif match.startswith('dart:'):
                continue
            else:
                target = os.path.normpath(os.path.join(os.path.dirname(fpath), match))
                imported_files.add(target)
    except Exception as e:
        pass

unimported = []
for fpath in all_dart_files:
    if fpath not in imported_files and not fpath.endswith('main.dart'):
        if not fpath.endswith('.g.dart') and not fpath.endswith('.freezed.dart'):
            unimported.append(fpath)

print('--- UNIMPORTED FILES ---')
for u in sorted(unimported):
    print(u)
