import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class LED extends CircuitComponent {
  @override
  String get name => 'LED';

  @override
  List<String> get aliases => ['LED', 'Light', 'Lamp', 'Bulb'];

  @override
  Map<String, dynamic> get metadata => {'forwardVoltage': 2.0};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  LED(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
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
        name: '-',
        direction: PortDirection.output,
        relativePosition: Offset(halfWidth, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void evaluate(SimulationTick tick) {
    if (_pins[0].state.logic == LogicState.high || _pins[0].state.voltage > 0) {
      _isOn = true;
      _pins[1].state = _pins[0].state.copyWith(voltage: _pins[0].state.voltage - metadata['forwardVoltage']);
    } else {
      _isOn = false;
      _pins[1].state.logic = LogicState.low;
      _pins[1].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.yellow.shade600 : Colors.grey;
}
