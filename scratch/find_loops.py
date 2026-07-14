import os

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                for i, line in enumerate(f, 1):
                    if 'while' in line or 'do {' in line or 'do' in line.split():
                        print(f'{path}:{i}: {line.strip()}')
