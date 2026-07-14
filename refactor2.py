import re

def fix_canvas_screen():
    path = r'c:\My World\gravity\notesketch_pro\lib\screens\canvas_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # block 1
    content = re.sub(
        r"final notebooks = ref\.read\(notebookProvider\);\s*final notebook = notebooks\.firstWhere\(\(n\) => n\.id == widget\.notebookId\);\s*final existingPage = notebook\.pages\.firstWhere\(",
        r"final canvases = ref.read(canvasProvider);\n    final existingPage = canvases.firstWhere(",
        content
    )
    content = content.replace("ref.read(notebookProvider.notifier)", "ref.read(canvasProvider.notifier)")
    content = content.replace(".updatePage(widget.notebookId, updatedPage);", ".updateCanvas(updatedPage);")
    
    # block 2
    content = re.sub(
        r"final notebooks = ref\.read\(notebookProvider\);\s*final notebook = notebooks\.firstWhere\(\(n\) => n\.id == notebookIdToSave\);\s*final existingPage = notebook\.pages\.firstWhere\(",
        r"final canvases = ref.read(canvasProvider);\n      final existingPage = canvases.firstWhere(",
        content
    )
    content = content.replace(".updatePage(notebookIdToSave, updatedPage);", ".updateCanvas(updatedPage);")
    
    # block 3
    content = content.replace(".renamePage(notebookId, page.id, controller.text.trim());", ".renameCanvas(page.id, controller.text.trim());")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done fixing canvas_screen.dart")

if __name__ == '__main__':
    fix_canvas_screen()
