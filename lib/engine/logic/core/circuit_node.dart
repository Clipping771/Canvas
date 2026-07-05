import '../models/circuit_pin.dart';

class CircuitNode {
  final String id;
  
  /// The true voltage of this node calculated by the MNA solver.
  double voltage = 0.0;
  
  /// Whether this node's voltage is fixed (e.g. Ground).
  bool isFixed = false;

  /// All component pins that are electrically connected to this node.
  final List<CircuitPin> connectedPins = [];

  CircuitNode({required this.id});

  void addPin(CircuitPin pin) {
    if (!connectedPins.contains(pin)) {
      connectedPins.add(pin);
    }
  }

  void mergeWith(CircuitNode other) {
    for (var pin in other.connectedPins) {
      if (!connectedPins.contains(pin)) {
        connectedPins.add(pin);
      }
    }
  }
}
