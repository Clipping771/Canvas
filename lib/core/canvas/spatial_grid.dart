import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';

class SpatialGrid {
  // Cell size determines the granularity of the grid.
  // 500x500 is a reasonable chunk size for an infinite canvas.
  static const double cellSize = 500.0;

  final Map<String, List<Stroke>> _cells = {};
  
  void clear() {
    _cells.clear();
  }

  String _getCellKey(int x, int y) {
    return '${x}_$y';
  }

  void insert(Stroke stroke) {
    final bounds = stroke.bounds;
    if (bounds.isEmpty) return;

    final startX = (bounds.left / cellSize).floor();
    final startY = (bounds.top / cellSize).floor();
    final endX = (bounds.right / cellSize).floor();
    final endY = (bounds.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        final key = _getCellKey(x, y);
        _cells.putIfAbsent(key, () => []).add(stroke);
      }
    }
  }

  void remove(Stroke stroke) {
    final bounds = stroke.bounds;
    if (bounds.isEmpty) return;

    final startX = (bounds.left / cellSize).floor();
    final startY = (bounds.top / cellSize).floor();
    final endX = (bounds.right / cellSize).floor();
    final endY = (bounds.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        final key = _getCellKey(x, y);
        _cells[key]?.remove(stroke);
        if (_cells[key]?.isEmpty ?? false) {
          _cells.remove(key);
        }
      }
    }
  }

  void update(Stroke oldStroke, Stroke newStroke) {
    remove(oldStroke);
    insert(newStroke);
  }

  void build(List<Stroke> strokes) {
    clear();
    for (final stroke in strokes) {
      insert(stroke);
    }
  }

  /// Returns all strokes that could potentially intersect the given rect.
  /// Using a Set internally to guarantee no duplicates if a stroke spans multiple cells.
  List<Stroke> query(Rect viewport) {
    if (viewport.isEmpty) return [];

    final startX = (viewport.left / cellSize).floor();
    final startY = (viewport.top / cellSize).floor();
    final endX = (viewport.right / cellSize).floor();
    final endY = (viewport.bottom / cellSize).floor();

    final result = <Stroke>{};

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        final key = _getCellKey(x, y);
        final strokesInCell = _cells[key];
        if (strokesInCell != null) {
          result.addAll(strokesInCell);
        }
      }
    }

    return result.toList();
  }
}
