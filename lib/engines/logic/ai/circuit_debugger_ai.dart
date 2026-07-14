import 'package:flutter/foundation.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';

/// An AI assistant that analyzes a circuit for common mistakes and faults.
class CircuitDebuggerAi {
  /// Analyzes the current active components and returns a list of warnings or feedback.
  List<String> analyzeCircuit(List<CircuitComponent> components) {
    List<String> feedback = [];
    debugPrint(
      "AI DEBUGGER: components = ${components.map((c) => c.type).toList()}",
    );

    bool hasBattery = components.any(
      (c) => c.type.toLowerCase() == 'battery' || c.type.toLowerCase() == 'vcc',
    );
    bool hasGround = components.any(
      (c) => c.type.toLowerCase() == 'ground' || c.type.toLowerCase() == 'gnd',
    );

    debugPrint("AI DEBUGGER: hasBattery=$hasBattery, hasGround=$hasGround");

    if (!hasBattery) {
      feedback.add('⚠️ No power source detected. Add a battery or VCC.');
    }
    if (!hasGround) {
      feedback.add(
        '⚠️ Circuit is floating. Add a Ground connection for proper reference.',
      );
    }

    // Check for LEDs without current limiting resistors
    for (var comp in components) {
      if (comp.type.toLowerCase() == 'led') {
        // Basic heuristic: Is there a resistor in the circuit at all?
        // In a real implementation, it would trace the specific loop containing the LED.
        bool hasResistor = components.any(
          (c) => c.type.toLowerCase() == 'resistor',
        );
        if (!hasResistor) {
          feedback.add(
            '🔥 Warning: LED might burn out! Consider adding a current-limiting resistor in series.',
          );
        }
      }
    }

    return feedback;
  }
}
