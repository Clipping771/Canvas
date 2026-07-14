import re
import os

def replace_in_file(path, replacements):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    home_path = r'c:\My World\gravity\notesketch_pro\lib\screens\home_screen.dart'
    canvas_path = r'c:\My World\gravity\notesketch_pro\lib\screens\canvas_screen.dart'
    
    home_replacements = [
        ("import '../providers/notebook_provider.dart';", "import '../providers/canvas_provider.dart';"),
        ("ref.read(notebookProvider.notifier).deleteAllNotebooks();", "ref.read(canvasProvider.notifier).deleteAllCanvases();"),
        ("final notebooks = ref.watch(notebookProvider);", "final notebooks = ref.watch(canvasProvider);"),
        ("ref.read(notebookProvider.notifier).addNotebook('My Notebook');", "ref.read(canvasProvider.notifier).addCanvas(title: 'My Canvas');"),
        ("final defaultNotebook = ref.read(notebookProvider).first;", "final defaultNotebook = ref.read(canvasProvider).first;"),
        ("await ref.read(notebookProvider.notifier).addPage(defaultNotebook.id);", ""),
        ("final updatedNotebook = ref.read(notebookProvider).firstWhere((n) => n.id == defaultNotebook.id);", "final updatedNotebook = ref.read(canvasProvider).firstWhere((n) => n.id == defaultNotebook.id);"),
    ]
    
    canvas_replacements = [
        ("import '../providers/notebook_provider.dart';", "import '../providers/canvas_provider.dart';"),
        ("final notebooks = ref.read(notebookProvider);", "final notebooks = ref.read(canvasProvider);"),
        ("final notebooks = ref.watch(notebookProvider);", "final notebooks = ref.watch(canvasProvider);"),
        ("await ref.read(notebookProvider.notifier).addPage(widget.notebookId);", "await ref.read(canvasProvider.notifier).addCanvas();"),
        ("final updatedNotebook = ref.read(notebookProvider).firstWhere((n) => n.id == widget.notebookId);", "final updatedNotebook = ref.read(canvasProvider).firstWhere((n) => n.id == widget.canvasId, orElse: () => ref.read(canvasProvider).last);"),
        (".read(notebookProvider.notifier)", ".read(canvasProvider.notifier)"),
        ("await CloudSyncService().syncNotebookToCloud(notebook);", "await CloudSyncService().syncCanvasToCloud(page);"),
        ("ref.read(notebookProvider.notifier).deletePage(notebook.id, page.id);", "ref.read(canvasProvider.notifier).deleteCanvas(page.id);"),
        ("widget.notebookId", "widget.canvasId")
    ]
    
    replace_in_file(home_path, home_replacements)
    replace_in_file(canvas_path, canvas_replacements)
    print("Fixed specific compilation errors.")

if __name__ == '__main__':
    main()
