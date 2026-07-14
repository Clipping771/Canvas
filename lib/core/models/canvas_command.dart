import 'package:vinci_board/core/models/stroke.dart';

abstract class CanvasCommand {
  void execute(List<Stroke> strokes);
  void undo(List<Stroke> strokes);
}

class AddStrokeCommand implements CanvasCommand {
  final Stroke stroke;
  AddStrokeCommand(this.stroke);

  @override
  void execute(List<Stroke> strokes) {
    strokes.add(stroke);
  }

  @override
  void undo(List<Stroke> strokes) {
    strokes.removeWhere((s) => s.id == stroke.id);
  }
}

class AddStrokesCommand implements CanvasCommand {
  final List<Stroke> strokesToAdd;
  AddStrokesCommand(this.strokesToAdd);

  @override
  void execute(List<Stroke> strokes) {
    strokes.addAll(strokesToAdd);
  }

  @override
  void undo(List<Stroke> strokes) {
    final idsToRemove = strokesToAdd.map((s) => s.id).toSet();
    strokes.removeWhere((s) => idsToRemove.contains(s.id));
  }
}

class RemoveStrokesCommand implements CanvasCommand {
  final List<Stroke> strokesToRemove;
  RemoveStrokesCommand(this.strokesToRemove);

  @override
  void execute(List<Stroke> strokes) {
    final idsToRemove = strokesToRemove.map((s) => s.id).toSet();
    strokes.removeWhere((s) => idsToRemove.contains(s.id));
  }

  @override
  void undo(List<Stroke> strokes) {
    strokes.addAll(strokesToRemove);
  }
}

class MoveStrokesCommand implements CanvasCommand {
  final List<Stroke> oldStrokes;
  final List<Stroke> newStrokes;

  MoveStrokesCommand(this.oldStrokes, this.newStrokes);

  @override
  void execute(List<Stroke> strokes) {
    final idsToUpdate = oldStrokes.map((s) => s.id).toSet();
    for (int i = 0; i < strokes.length; i++) {
      if (idsToUpdate.contains(strokes[i].id)) {
        final newS = newStrokes.firstWhere((ns) => ns.id == strokes[i].id);
        strokes[i] = newS;
      }
    }
  }

  @override
  void undo(List<Stroke> strokes) {
    final idsToUpdate = newStrokes.map((s) => s.id).toSet();
    for (int i = 0; i < strokes.length; i++) {
      if (idsToUpdate.contains(strokes[i].id)) {
        final oldS = oldStrokes.firstWhere((os) => os.id == strokes[i].id);
        strokes[i] = oldS;
      }
    }
  }
}

class ClearCanvasCommand implements CanvasCommand {
  final List<Stroke> previousStrokes;
  ClearCanvasCommand(this.previousStrokes);

  @override
  void execute(List<Stroke> strokes) {
    strokes.clear();
  }

  @override
  void undo(List<Stroke> strokes) {
    strokes.addAll(previousStrokes);
  }
}

class SnapshotCommand implements CanvasCommand {
  final List<Stroke> oldStrokes;
  final List<Stroke> newStrokes;

  SnapshotCommand(this.oldStrokes, this.newStrokes);

  @override
  void execute(List<Stroke> strokes) {
    strokes.clear();
    strokes.addAll(newStrokes);
  }

  @override
  void undo(List<Stroke> strokes) {
    strokes.clear();
    strokes.addAll(oldStrokes);
  }
}
