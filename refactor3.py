import re

def fix_all():
    path = r'c:\My World\gravity\notesketch_pro\lib\screens\canvas_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    content = content.replace("notebookProvider", "canvasProvider")
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

    print("Done fixing all notebookProvider")

if __name__ == '__main__':
    fix_all()
