// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';

class SpatialIndex {
  // A simple grid-based spatial hash index.
  // We divide the infinite canvas into cells of size cellSize.
  final double cellSize;
  final Map<String, List<Stroke>> _grid = {};

  SpatialIndex({this.cellSize = 500.0});

  void buildIndex(List<Stroke> strokes) {
    _grid.clear();
    
    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      insert(stroke);
    }
  }

  void insert(Stroke stroke) {
    if (stroke.points.isEmpty) return;
    final bounds = stroke.bounds;
    final minCol = (bounds.left / cellSize).floor();
    final maxCol = (bounds.right / cellSize).floor();
    final minRow = (bounds.top / cellSize).floor();
    final maxRow = (bounds.bottom / cellSize).floor();

    for (int col = minCol; col <= maxCol; col++) {
      for (int row = minRow; row <= maxRow; row++) {
        final key = '$col,$row';
        _grid.putIfAbsent(key, () => []).add(stroke);
      }
    }
  }

  void remove(Stroke stroke) {
    if (stroke.points.isEmpty) return;
    final bounds = stroke.bounds;
    final minCol = (bounds.left / cellSize).floor();
    final maxCol = (bounds.right / cellSize).floor();
    final minRow = (bounds.top / cellSize).floor();
    final maxRow = (bounds.bottom / cellSize).floor();

    for (int col = minCol; col <= maxCol; col++) {
      for (int row = minRow; row <= maxRow; row++) {
        final key = '$col,$row';
        _grid[key]?.removeWhere((s) => s.id == stroke.id);
        if (_grid[key]?.isEmpty ?? false) {
          _grid.remove(key);
        }
      }
    }
  }

  void update(Stroke oldStroke, Stroke newStroke) {
    remove(oldStroke);
    insert(newStroke);
  }



  List<Stroke> queryRect(Rect queryArea) {
    final minCol = (queryArea.left / cellSize).floor();
    final maxCol = (queryArea.right / cellSize).floor();
    final minRow = (queryArea.top / cellSize).floor();
    final maxRow = (queryArea.bottom / cellSize).floor();

    final resultIds = <String>{};
    final results = <Stroke>[];

    for (int col = minCol; col <= maxCol; col++) {
      for (int row = minRow; row <= maxRow; row++) {
        final key = '$col,$row';
        final cell = _grid[key];
        if (cell != null) {
          for (var stroke in cell) {
            if (!resultIds.contains(stroke.id)) {
              if (stroke.bounds.overlaps(queryArea)) {
                results.add(stroke);
                resultIds.add(stroke.id);
              }
            }
          }
        }
      }
    }

    return results;
  }

  List<Stroke> queryPoint(Offset point) {
    final queryArea = Rect.fromCenter(center: point, width: 1, height: 1);
    final candidates = queryRect(queryArea);

    // Exact path testing for candidates
    return candidates.where((s) => s.path.contains(point)).toList();
  }
}
