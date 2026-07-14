import 'dart:ui';
import 'package:vinci_board/engines/logic/core/circuit_node.dart';

/// Suggests optimal wiring connections for users automatically.
class AutoRouterAi {
  /// Given a list of nodes that need to be connected, it suggests physical path routing.
  List<Offset> suggestRoute(CircuitNode source, CircuitNode destination) {
    // Stub for advanced pathfinding AI.
    // It would look at the canvas obstacles and suggest a clean, right-angled wire path.
    return [];
  }

  /// Suggests missing connections. E.g., if an MCU pin needs 5V, it returns a suggested wire to VCC.
  String suggestMissingConnection(String componentId, String pinName) {
    if (pinName.toLowerCase() == 'vcc' || pinName.toLowerCase() == 'power') {
      return 'Suggestion: Connect $pinName of $componentId to a 5V Battery Source.';
    }
    if (pinName.toLowerCase() == 'gnd' || pinName.toLowerCase() == 'ground') {
      return 'Suggestion: Connect $pinName of $componentId to Ground.';
    }
    return '';
  }
}
