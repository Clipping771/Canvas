import re

path = r"c:\My World\gravity\notesketch_pro\lib\presentation\providers\drawing_provider.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add _commitCommand
commit_code = """
  void _commitCommand(CanvasCommand cmd) {
    final newStrokes = List<Stroke>.from(state.strokes);
    cmd.execute(newStrokes);
    final newUndo = List<CanvasCommand>.from(state.undoHistory)..add(cmd);
    if (newUndo.length > 50) newUndo.removeAt(0); // enforce limit
    state = state.copyWith(strokes: newStrokes, undoHistory: newUndo, redoHistory: []);
  }

"""

if "void _commitCommand" not in content:
    content = content.replace("class DrawingNotifier extends Notifier<DrawingState> {", "class DrawingNotifier extends Notifier<DrawingState> {\n" + commit_code)

# 2. Rewrite startStroke
start_regex = re.compile(r"void startStroke\(Offset position\)\s*\{.*?\}", re.DOTALL)
# Wait, startStroke has braces inside. I'll just find the exact block using string replacement.
