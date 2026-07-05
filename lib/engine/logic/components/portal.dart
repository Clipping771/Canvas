import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class PortalComponent extends CircuitComponent {
  @override
  String get name => 'Portal';

  @override
  List<String> get aliases => ['Portal'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  PortalComponent(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'IN',
        direction: PortDirection.input,
        relativePosition: const Offset(0, 0),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'OUT',
        direction: PortDirection.output,
        relativePosition: const Offset(0, 0),
      )
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void evaluate(SimulationTick tick) {
    // Evaluation handled externally in TeslaEngine to transmit power across portals
    _isOn = (_pins[0].state.logic == LogicState.high || _pins[0].state.voltage > 0) ||
            (_pins[1].state.logic == LogicState.high || _pins[1].state.voltage > 0);
  }

  @override
  Color getActiveColor() => _isOn ? Colors.orange : Colors.blue.withOpacity(0.5);
}
