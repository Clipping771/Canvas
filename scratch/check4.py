import re
from collections import Counter

with open('analyze_out4.txt', 'r', encoding='utf-16le', errors='ignore') as f:
    lines = f.readlines()

errors = []
for line in lines:
    if '-' in line and ':' in line:
        parts = line.strip().split(' - ')
        if len(parts) >= 3:
            errors.append(parts[-1])

c = Counter(errors)
for k, v in c.most_common():
    print(f'{v}: {k}')
