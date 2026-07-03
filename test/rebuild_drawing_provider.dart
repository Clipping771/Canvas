import 'dart:io';

void main() {
  final file = File('c:/My World/gravity/notesketch_pro/lib/providers/drawing_provider.dart');
  var content = file.readAsStringSync();
  
  // 1. Remove WorldSimulation and ShapeRecognizer imports
  content = content.replaceAll("import '../engine/spatial/shape_recognizer.dart';", "");
  
  // 2. Remove lastDetectedShape from DrawingState
  content = content.replaceAll("final ShapeType? lastDetectedShape;", "");
  content = content.replaceAll("final Rect? lastDetectedShapeBounds;", "");
  content = content.replaceAll("ShapeType? lastDetectedShape,", "");
  content = content.replaceAll("Rect? lastDetectedShapeBounds,", "");
  content = content.replaceAll("this.lastDetectedShape,", "");
  content = content.replaceAll("this.lastDetectedShapeBounds,", "");
  content = content.replaceAll("lastDetectedShape: lastDetectedShape ?? this.lastDetectedShape,", "");
  content = content.replaceAll("lastDetectedShapeBounds: lastDetectedShapeBounds ?? this.lastDetectedShapeBounds,", "");

  // 3. Add _enforceHistoryLimit
  final enforceLimitCode = '''
  void _enforceHistoryLimit(List<List<Stroke>> history, List<List<Stroke>> redoHistory, List<Stroke> currentStrokes) {
    while (history.length > 50) {
      final discarded = history.removeAt(0);
      for (final stroke in discarded) {
        if (stroke.decodedImage != null) {
          bool isReferenced = false;
          
          for (final s in currentStrokes) {
            if (s.decodedImage == stroke.decodedImage) {
              isReferenced = true;
              break;
            }
          }
          if (isReferenced) continue;
          
          for (final snapshot in history) {
            for (final s in snapshot) {
              if (s.decodedImage == stroke.decodedImage) {
                isReferenced = true;
                break;
              }
            }
            if (isReferenced) break;
          }
          if (isReferenced) continue;
          
          for (final snapshot in redoHistory) {
            for (final s in snapshot) {
              if (s.decodedImage == stroke.decodedImage) {
                isReferenced = true;
                break;
              }
            }
            if (isReferenced) break;
          }
          if (isReferenced) continue;
          
          stroke.decodedImage!.dispose();
        }
      }
    }
  }

  void _pushUndo() {''';
  
  content = content.replaceAll('  void _pushUndo() {', enforceLimitCode);

  // 4. Inject _enforceHistoryLimit calls
  content = content.replaceAll(
    '..add(List.from(state.strokes));',
    '..add(List.from(state.strokes));\n    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);'
  );
  content = content.replaceAll(
    'newUndoHistory.add(List.from(state.strokes));',
    'newUndoHistory.add(List.from(state.strokes));\n    _enforceHistoryLimit(newUndoHistory, [], state.strokes);'
  );

  // 5. Remove tweenStrokes
  final tweenStrokesStart = content.indexOf('  Future<void> tweenStrokes(');
  if (tweenStrokesStart != -1) {
    final removeStrokesStart = content.indexOf('  void removeStrokes(List<Stroke> strokesToRemove) {');
    content = content.replaceRange(tweenStrokesStart, removeStrokesStart, '');
  }

  // 6. Rewrite eraseAtPoint and add commitErasure
  final eraseAtPointStart = content.indexOf('  void eraseAtPoint(Offset point, double radius) {');
  
  final eraserLogic = '''
  void eraseAtPoint(Offset point, double radius) {
    if (state.strokes.isEmpty) return;
  }

  void commitErasure() {
    if (_currentStroke == null || _currentStroke!.toolType != ToolType.eraser || state.strokes.isEmpty) {
      return;
    }

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    double eMinX = double.infinity, eMinY = double.infinity;
    double eMaxX = double.negativeInfinity, eMaxY = double.negativeInfinity;
    for (var p in _currentStroke!.points) {
      if (p.dx < eMinX) eMinX = p.dx;
      if (p.dy < eMinY) eMinY = p.dy;
      if (p.dx > eMaxX) eMaxX = p.dx;
      if (p.dy > eMaxY) eMaxY = p.dy;
    }
    
    final eraserRadius = _currentStroke!.size;
    final eraserBounds = Rect.fromLTRB(
      eMinX - eraserRadius, 
      eMinY - eraserRadius, 
      eMaxX + eraserRadius, 
      eMaxY + eraserRadius
    );

    final eraserPoints = _currentStroke!.points;
    final radiusSq = eraserRadius * eraserRadius;

    final newStrokes = state.strokes.where((stroke) {
      if (!stroke.bounds.overlaps(eraserBounds)) {
        return true; 
      }
      if (stroke.text != null) {
        final p = stroke.points.first;
        for (final ep in eraserPoints) {
          if ((p - ep).distanceSquared <= radiusSq) return false; 
        }
        return true;
      }
      for (final sp in stroke.points) {
        for (final ep in eraserPoints) {
          if ((sp - ep).distanceSquared <= radiusSq) {
            return false; 
          }
        }
      }
      return true;
    }).toList();

    _currentStroke = null;

    if (newStrokes.length != state.strokes.length) {
      state = state.copyWith(strokes: newStrokes, undoHistory: newUndoHistory, redoHistory: []);
    }
  }

''';
  
  // Actually, we should replace from `eraseAtPoint` to `void setTool(ToolType tool) {`
  final setToolStart = content.indexOf('  void setTool(ToolType tool) {');
  if (eraseAtPointStart != -1 && setToolStart != -1) {
     content = content.replaceRange(eraseAtPointStart, setToolStart, eraserLogic);
  }

  // 7. Remove ShapeRecognizer logic from endStroke()
  final shapeRecognizerLogicStart = content.indexOf('      // Auto-correct shapes if in discovery mode');
  final shapeRecognizerLogicEnd = content.indexOf('      ref.read(gamificationProvider.notifier).addXp(5);');
  if (shapeRecognizerLogicStart != -1 && shapeRecognizerLogicEnd != -1) {
      content = content.replaceRange(shapeRecognizerLogicStart, shapeRecognizerLogicEnd, '');
  }

  file.writeAsStringSync(content);
  print('Rebuilt drawing_provider.dart successfully.');
}
