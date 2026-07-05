import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class Resistor extends CircuitComponent {
  @override
  String get name => 'Resistor';

  @override
  List<String> get aliases => ['Resistor', 'Ohm'];

  @override
  Map<String, dynamic> get metadata => {'resistance': 330.0}; // 330 Ohms

  late final List<CircuitPin> _pins;
  double _voltageDrop = 2.0; // Simplified voltage drop for simulation

  Resistor(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'IN',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 0),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'OUT',
        direction: PortDirection.output,
        relativePosition: Offset(halfWidth, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void evaluate(SimulationTick tick) {
    final inputVoltage = _pins[0].state.voltage;
    
    if (inputVoltage > 0) {
      double outputVoltage = inputVoltage - _voltageDrop;
      if (outputVoltage < 0) outputVoltage = 0;
      
      _pins[1].state.voltage = outputVoltage;
      // If voltage drops below 1.5V, it might be considered LOW logic
      _pins[1].state.logic = outputVoltage >= 1.5 ? LogicState.high : LogicState.low;
    } else {
      _pins[1].state.logic = LogicState.low;
      _pins[1].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => Colors.brown.shade400;
}
