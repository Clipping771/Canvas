import 'package:vinci_board/engines/logic/models/circuit_component.dart';

/// Evaluates digital logic gates separately from analog MNA.
/// Digital signals are propagated forward from inputs to outputs.
class LogicEngine {
  /// Evaluates all digital components in topological order (if possible)
  /// or iteratively until stabilization (for feedback loops).
  void evaluateDigitalCircuits(List<CircuitComponent> activeComponents) {
    bool changed = true;
    int maxIterations = 100;
    int iterations = 0;

    // Iterative evaluation to handle basic feedback loops (like RS latches)
    while (changed && iterations < maxIterations) {
      changed = false;

      for (var comp in activeComponents) {
        if (_isDigital(comp.type)) {
          bool outputChanged = _evaluateGate(comp);
          if (outputChanged) changed = true;
        }
      }

      iterations++;
    }
  }

  bool _isDigital(String type) {
    const digitalTypes = ['and', 'or', 'not', 'xor', 'nand', 'nor'];
    return digitalTypes.contains(type);
  }

  bool _evaluateGate(CircuitComponent gate) {
    // Basic evaluation stub.
    // In a full implementation, reads input pins, computes logic function,
    // and updates output pins. Returns true if the output state changed.
    return false;
  }
}
