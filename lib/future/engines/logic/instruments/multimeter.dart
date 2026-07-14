import 'package:vinci_board/engines/logic/core/circuit_node.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';

/// A virtual Multimeter used to measure Voltage, Current, and Resistance.
class Multimeter {
  String mode = 'voltage'; // 'voltage', 'current', 'resistance'

  /// Measures voltage difference between two pins.
  double measureVoltage(CircuitPin redProbe, CircuitPin blackProbe) {
    return redProbe.state.voltage - blackProbe.state.voltage;
  }

  /// Measures current flowing into a pin.
  double measureCurrent(CircuitPin inlineProbe) {
    return inlineProbe.state.current;
  }

  /// Measures resistance between two nodes (Requires MNA solver test injection).
  double measureResistance(CircuitNode nodeA, CircuitNode nodeB) {
    // In a real simulator, this involves injecting a 1A test current
    // and measuring the voltage difference to get R = V/I.
    return double.infinity; // Default open circuit
  }
}
