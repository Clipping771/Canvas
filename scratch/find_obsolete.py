import os, glob

lib_dir = 'lib'
all_dart_files = glob.glob(os.path.join(lib_dir, '**/*.dart'), recursive=True)

keywords = ['old', 'backup', 'v1', 'copy', 'experiment', 'obsolete', 'deprecated', 'temp', 'scratch']

found = []
for f in all_dart_files:
    fname = os.path.basename(f).lower()
    for k in keywords:
        if k in fname:
            found.append(f)
            break

print("--- OBSOLETE FILES ---")
for f in found: print(f)
