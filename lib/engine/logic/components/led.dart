import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';
import '../core/mna_solver.dart';

class LED extends CircuitComponent {
  @override
  String get name => 'LED';

  @override
  List<String> get aliases => ['LED', 'Light', 'Lamp', 'Bulb'];

  @override
  Map<String, dynamic> get metadata => {'forwardVoltage': 2.0, 'resistance': 50.0, 'maxPower': 0.1};

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
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;
    double res = metadata['resistance'] as double;
    double conductance = isBurnedOut ? 1.0 / 1e9 : 1.0 / res;
    solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, conductance);
  }

  @override
  void evaluate(SimulationTick tick) {
    super.evaluate(tick);
    if (isBurnedOut) {
      _isOn = false;
      return;
    }
    
    // In MNA, we check the voltage drop across the LED
    double vDrop = (_pins[0].state.voltage - _pins[1].state.voltage).abs();
    
    if (vDrop >= metadata['forwardVoltage']) {
      _isOn = true;
    } else {
      _isOn = false;
    }
  }

  @override
  Color getActiveColor() {
    if (isBurnedOut) return Colors.black54;
    return _isOn ? Colors.yellow.shade600 : Colors.grey;
  }
}
