with open('analyze_out4.txt', 'r', encoding='utf-16le', errors='ignore') as f:
    for line in f:
        if 'groupValue' in line:
            print(line.strip())
