import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class Battery extends CircuitComponent {
  @override
  String get name => 'Battery';

  @override
  List<String> get aliases => ['Battery', 'VCC', 'Power'];

  @override
  Map<String, dynamic> get metadata => {'voltage': 9.0};

  late final List<CircuitPin> _pins;

  Battery(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_out',
        name: '+',
        direction: PortDirection.output,
        relativePosition: Offset(halfWidth, 0),
        state: SignalState(logic: LogicState.high, voltage: 9.0),
      )
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void evaluate(SimulationTick tick) {
    // Battery constantly outputs HIGH.
    _pins[0].state.logic = LogicState.high;
    _pins[0].state.voltage = 9.0;
  }

  @override
  Color getActiveColor() => Colors.red.shade700;
}
