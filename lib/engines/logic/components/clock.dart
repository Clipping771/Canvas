import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/models/logic_state.dart';
import 'package:vinci_board/engines/logic/models/signal_state.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';

class Clock extends CircuitComponent {
  @override
  String get name => 'Clock';

  @override
  List<String> get aliases => ['Clock', 'Oscillator', 'Pulse'];

  @override
  Map<String, dynamic> get metadata => {'frequency': 1.0}; // 1 Hz by default

  late final List<CircuitPin> _pins;
  bool _isOn = false;
  double _timeAccumulator = 0.0;

  Clock(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_out',
        name: 'OUT',
        direction: PortDirection.output,
        relativePosition: Offset(halfWidth, 0),
        state: SignalState(logic: LogicState.low, voltage: 0.0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void evaluate(SimulationTick tick) {
    _timeAccumulator += tick.deltaTimeSeconds;

    // Toggle based on frequency
    final period = 1.0 / (metadata['frequency'] as double);
    final halfPeriod = period / 2.0;

    if (_timeAccumulator >= halfPeriod) {
      _isOn = !_isOn;
      _timeAccumulator -= halfPeriod;
    }

    if (_isOn) {
      _pins[0].state.logic = LogicState.high;
      _pins[0].state.voltage = 9.0;
    } else {
      _pins[0].state.logic = LogicState.low;
      _pins[0].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.purpleAccent : Colors.grey;
}
