with open('analyze_out3.txt', 'r', encoding='utf-16le', errors='ignore') as f:
    for line in f:
        if 'deprecated_member_use' in line:
            print(line.strip())
