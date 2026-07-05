import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class Motor extends CircuitComponent {
  @override
  String get name => 'Motor';

  @override
  List<String> get aliases => ['Motor', 'Engine', 'Fan'];

  @override
  Map<String, dynamic> get metadata => {'maxRpm': 3000.0, 'operatingVoltage': 9.0, 'resistance': 100.0, 'maxPower': 2.0};

  late final List<CircuitPin> _pins;
  double _currentRpm = 0.0;
  bool _isOn = false;

  @override
  bool get isAnimated => _isOn && !isBurnedOut;

  Motor(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
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
      _currentRpm = 0.0;
      return;
    }
    
    // MNA voltage drop
    double vDrop = (_pins[0].state.voltage - _pins[1].state.voltage).abs();
    final operatingVoltage = metadata['operatingVoltage'] as double;
    final maxRpm = metadata['maxRpm'] as double;
    
    if (vDrop >= 1.0) { // arbitrary threshold to turn on
      _isOn = true;
      _currentRpm = (vDrop / operatingVoltage) * maxRpm;
    } else {
      _isOn = false;
      _currentRpm = 0.0;
    }
  }

  @override
  Color getActiveColor() {
    if (isBurnedOut) return Colors.black54;
    return _isOn ? Colors.blue.shade400 : Colors.grey;
  }
}
