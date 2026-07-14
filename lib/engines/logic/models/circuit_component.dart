import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';

abstract class CircuitComponent {
  final String id;
  final Stroke originalStroke;

  double powerDissipated = 0.0;
  bool isBurnedOut = false;
  int _burnFrames = 0;

  CircuitComponent({required this.id, required this.originalStroke});

  String get name;
  String get type => name;
  List<String> get aliases;
  Map<String, dynamic> get metadata;
  List<CircuitPin> get pins;

  void evaluate(SimulationTick tick) {
    if (pins.length >= 2) {
      double vDrop = (pins[0].state.voltage - pins[1].state.voltage).abs();
      double resistance = metadata['resistance'] as double? ?? 0.0;
      if (resistance > 0) {
        powerDissipated = (vDrop * vDrop) / resistance;
      } else {
        powerDissipated = 0.0;
      }

      double maxPower = metadata['maxPower'] as double? ?? double.infinity;
      if (powerDissipated > maxPower) {
        _burnFrames++;
        if (_burnFrames > 30) {
          isBurnedOut = true;
        }
      } else {
        _burnFrames = 0;
      }
    }
  }

  /// Apply MNA stamps to the solver. Override this for analog components.
  void applyMNA(dynamic solver) {}

  /// Update component properties (resistance, voltage) by parsing its text.
  void updatePropertiesFromText(String text) {}

  // SPICE Export Hook
  String toSpice(Map<String, int> nodeMap) {
    if (pins.isEmpty) return '';
    String p1 = pins.isNotEmpty
        ? (nodeMap[pins[0].nodeId]?.toString() ?? '0')
        : '0';
    String p2 = pins.length > 1
        ? (nodeMap[pins[1].nodeId]?.toString() ?? '0')
        : '0';

    String prefix = name.substring(0, 1).toUpperCase();
    if (name.toLowerCase() == 'battery') prefix = 'V';

    // Attempt to get value
    String val = '1';
    if (metadata.containsKey('resistance')) {
      val = '${metadata['resistance']}';
    } else if (metadata.containsKey('capacitance'))
      val = '${metadata['capacitance']}';
    else if (metadata.containsKey('inductance'))
      val = '${metadata['inductance']}';
    else if (metadata.containsKey('voltage'))
      val = '${metadata['voltage']}';

    return '$prefix$id $p1 $p2 $val';
  }

  Color getActiveColor();

  bool get isAnimated => false;

  bool get isActive => false;

  void resetSimulationState() {}
}
