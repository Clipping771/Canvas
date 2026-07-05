import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';
import '../core/mna_solver.dart';

class SwitchComponent extends CircuitComponent {
  @override
  String get name => 'Switch';

  @override
  List<String> get aliases => ['Switch', 'Toggle'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  SwitchComponent(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    if (stroke.text != null && stroke.text!.toLowerCase().contains('on')) {
      _isOn = true;
    }
    double halfWidth = 50.0;
    if (stroke.text != null) {
      // Estimate width based on character count and font size (stroke.size)
      // Average char width is roughly 0.6 * fontSize.
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
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;
    if (_isOn) {
      // 0.001 Ohms when ON (ideal wire)
      solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, 1.0 / 0.001);
    }
  }

  @override
  void evaluate(SimulationTick tick) {
    if (_isOn) {
      _pins[1].state = _pins[0].state.copyWith();
    } else {
      _pins[1].state.logic = LogicState.floating;
      _pins[1].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.green : Colors.grey;
}
