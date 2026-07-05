import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class Oscilloscope extends CircuitComponent {
  @override
  String get name => 'Oscilloscope';

  @override
  List<String> get aliases => ['Oscilloscope', 'Scope'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  
  // History of voltages for rendering
  final List<double> voltageHistory = [];
  final int maxHistoryLength = 100;

  Oscilloscope(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'Probe',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;
  
  @override
  bool get isAnimated => true; // Always redraw to animate waveform

  @override
  void applyMNA(dynamic solver) {
    // Oscilloscope has ideal infinite resistance, so it doesn't stamp anything in MNA
  }

  @override
  void evaluate(SimulationTick tick) {
    double voltage = _pins[0].state.voltage;
    
    voltageHistory.add(voltage);
    if (voltageHistory.length > maxHistoryLength) {
      voltageHistory.removeAt(0);
    }
  }

  @override
  Color getActiveColor() => Colors.greenAccent;
}
