with open('analyze_out5.txt', 'r', encoding='utf-16le', errors='ignore') as f:
    for line in f:
        if ' - ' in line and ':' in line:
            if 'curly_braces_in_flow_control_structures' not in line:
                print(line.strip())
