import os

def fix_canvas(c):
    return c.replace('widget.canvas.', 'existingPage.')

fp = r'lib\presentation\screens\canvas_screen.dart'
try:
    with open(fp, 'r', encoding='utf-8') as f:
        content = f.read()
    content = fix_canvas(content)
    with open(fp, 'w', encoding='utf-8') as f:
        f.write(content)
except Exception as e:
    pass

