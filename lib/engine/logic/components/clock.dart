import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

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
    _pins = [
      CircuitPin(
        id: '${id}_out',
        name: 'OUT',
        direction: PortDirection.output,
        relativePosition: const Offset(50, 0),
        state: SignalState(logic: LogicState.low, voltage: 0.0),
      )
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
