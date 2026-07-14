import re

path = r"c:\My World\gravity\notesketch_pro\lib\presentation\providers\drawing_provider.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace _enforceHistoryLimit signature to take List<CanvasCommand> or remove it since _commitCommand does it
enforce_pattern = r"void _enforceHistoryLimit\(List<List<Stroke>> history,\s*List<List<Stroke>> redoHistory,\s*List<Stroke> currentStrokes\)\s*\{[\s\S]*?\}\n"
content = re.sub(enforce_pattern, "", content)

# 1. applyGravityToGroup:
#   _pushUndo();
#   ... state = state.copyWith(strokes: newStrokes);
# To:
#   final oldStrokes = List<Stroke>.from(state.strokes);
#   ...
#   _commitCommand(MoveStrokesCommand(oldStrokes, newStrokes));

def replace_push_undo_block(match):
    return ""

content = re.sub(r"^\s*void _pushUndo\(\)\s*\{[\s\S]*?\}\n", "", content, flags=re.MULTILINE)

# I will write a simple generic replace for all the other undo pushes:
#    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
#      ..add(List.from(state.strokes));
#    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);
# We just delete this.
content = re.sub(r"\s*final newUndoHistory = List<List<Stroke>>\.from\(state\.undoHistory\)\s*\.\.add\(List\.from\(state\.strokes\)\);\s*_enforceHistoryLimit\(newUndoHistory, state\.redoHistory, state\.strokes\);", "", content)

# Also there's one where it's split:
content = re.sub(r"\s*final newUndoHistory = List<List<Stroke>>\.from\(state\.undoHistory\);\s*newUndoHistory\.add\(List\.from\(state\.strokes\)\);\s*_enforceHistoryLimit\(newUndoHistory, \[\], state\.strokes\);\s*if \(newUndoHistory\.length > 50\) newUndoHistory\.removeAt\(0\);", "", content)


# Now we replace the `undoHistory: newUndoHistory,` and `redoHistory: [],` inside state.copyWith
content = re.sub(r"\s*undoHistory:\s*newUndoHistory,", "", content)
content = re.sub(r"\s*redoHistory:\s*\[\],", "", content)

# However, if we do this, NO HISTORY gets saved for those operations!
# We MUST implement a fallback SnapshotCommand!
# Let's write SnapshotCommand inside canvas_command.dart

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done")
