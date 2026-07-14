import 'dart:ui';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';

/// Represents a virtual breadboard mapping for the UI.
class Breadboard {
  // A standard breadboard has interconnected rows and power rails.
  // This class manages mapping generic canvas coordinates to rigid breadboard holes.

  final Map<int, List<CircuitComponent>> _rows = {};

  /// Snaps a generic canvas coordinate to the nearest breadboard hole.
  Offset snapToGrid(Offset canvasPos) {
    const double gridSize = 10.0;
    double snappedX = (canvasPos.dx / gridSize).round() * gridSize;
    double snappedY = (canvasPos.dy / gridSize).round() * gridSize;
    return Offset(snappedX, snappedY);
  }

  /// Inserts a component pin into a specific breadboard row.
  void insertPin(int rowNumber, CircuitComponent component) {
    if (!_rows.containsKey(rowNumber)) {
      _rows[rowNumber] = [];
    }
    _rows[rowNumber]!.add(component);
  }

  /// Finds all components connected to the same row.
  List<CircuitComponent> getConnectedComponents(int rowNumber) {
    return _rows[rowNumber] ?? [];
  }
}
