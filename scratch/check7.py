with open('analyze_out7.txt', 'r', encoding='utf-16le', errors='ignore') as f:
    lines = [line.strip() for line in f if ' - ' in line and ':' in line]
    for line in lines:
        print(line)
