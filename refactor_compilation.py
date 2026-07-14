import re

def fix_canvas_screen_compilation_errors():
    path = r'c:\My World\gravity\notesketch_pro\lib\screens\canvas_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace specific remaining _currentPageId and NotePage
    content = content.replace("p.id == _currentPageId,", "p.id == _currentCanvasId,")
    content = content.replace("c.id == _currentPageId,", "c.id == _currentCanvasId,")
    content = content.replace("final currentPageIdToSave = _currentPageId;", "final currentPageIdToSave = _currentCanvasId;")
    content = content.replace("final updatedPage = NotePage(", "final updatedPage = AppCanvas(")
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    fix_canvas_screen_compilation_errors()
