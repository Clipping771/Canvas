import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class Ground extends CircuitComponent {
  @override
  String get name => 'Ground';

  @override
  List<String> get aliases => ['Ground', 'GND'];

  @override
  Map<String, dynamic> get metadata => {'voltage': 0.0};

  late final List<CircuitPin> _pins;

  Ground(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: '-',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 0),
        state: SignalState(logic: LogicState.low, voltage: 0.0),
      )
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void evaluate(SimulationTick tick) {
    _pins[0].state.logic = LogicState.low;
    _pins[0].state.voltage = 0.0;
  }

  @override
  Color getActiveColor() => Colors.green.shade700;
}
