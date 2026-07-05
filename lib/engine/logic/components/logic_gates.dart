import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class AndGate extends CircuitComponent {
  @override
  String get name => 'AND Gate';

  @override
  List<String> get aliases => ['AND Gate', 'AND'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  AndGate(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in1',
        name: 'A',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, -20),
      ),
      CircuitPin(
        id: '${id}_in2',
        name: 'B',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 20),
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
    bool in1High = _pins[0].state.logic == LogicState.high || _pins[0].state.voltage > 0;
    bool in2High = _pins[1].state.logic == LogicState.high || _pins[1].state.voltage > 0;
    
    if (in1High && in2High) {
      _isOn = true;
      _pins[2].state.logic = LogicState.high;
      _pins[2].state.voltage = 9.0;
    } else {
      _isOn = false;
      _pins[2].state.logic = LogicState.low;
      _pins[2].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.blue : Colors.grey;
}

class OrGate extends CircuitComponent {
  @override
  String get name => 'OR Gate';

  @override
  List<String> get aliases => ['OR Gate', 'OR'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  OrGate(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in1',
        name: 'A',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, -20),
      ),
      CircuitPin(
        id: '${id}_in2',
        name: 'B',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 20),
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
    bool in1High = _pins[0].state.logic == LogicState.high || _pins[0].state.voltage > 0;
    bool in2High = _pins[1].state.logic == LogicState.high || _pins[1].state.voltage > 0;
    
    if (in1High || in2High) {
      _isOn = true;
      _pins[2].state.logic = LogicState.high;
      _pins[2].state.voltage = 9.0;
    } else {
      _isOn = false;
      _pins[2].state.logic = LogicState.low;
      _pins[2].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.blue : Colors.grey;
}

class NotGate extends CircuitComponent {
  @override
  String get name => 'NOT Gate';

  @override
  List<String> get aliases => ['NOT Gate', 'NOT', 'Inverter'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  NotGate(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
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
    bool inHigh = _pins[0].state.logic == LogicState.high || _pins[0].state.voltage > 0;
    
    if (!inHigh) {
      _isOn = true;
      _pins[1].state.logic = LogicState.high;
      _pins[1].state.voltage = 9.0;
    } else {
      _isOn = false;
      _pins[1].state.logic = LogicState.low;
      _pins[1].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.blue : Colors.grey;
}
