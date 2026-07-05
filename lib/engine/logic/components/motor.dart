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
  Map<String, dynamic> get metadata => {'maxRpm': 3000.0, 'operatingVoltage': 9.0};

  late final List<CircuitPin> _pins;
  double _currentRpm = 0.0;
  bool _isOn = false;

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
  void evaluate(SimulationTick tick) {
    final inputVoltage = _pins[0].state.voltage;
    final operatingVoltage = metadata['operatingVoltage'] as double;
    final maxRpm = metadata['maxRpm'] as double;
    
    if (inputVoltage > 0) {
      _isOn = true;
      // Calculate RPM based on voltage proportion
      _currentRpm = (inputVoltage / operatingVoltage) * maxRpm;
      if (_currentRpm > maxRpm) _currentRpm = maxRpm;
      
      // Motor drops voltage to ground usually if directly connected
      _pins[1].state.voltage = 0.0;
      _pins[1].state.logic = LogicState.low;
    } else {
      _isOn = false;
      _currentRpm = 0.0;
      _pins[1].state.logic = LogicState.low;
      _pins[1].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() {
    if (!_isOn) return Colors.grey;
    // Map RPM to color brightness (faster = brighter cyan)
    final ratio = _currentRpm / (metadata['maxRpm'] as double);
    return Color.lerp(Colors.cyan.shade900, Colors.cyanAccent, ratio)!;
  }
}
