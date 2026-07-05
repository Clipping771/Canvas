import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';

class ScriptableChip extends CircuitComponent {
  @override
  String get name => 'MCU';

  @override
  List<String> get aliases => ['MCU', 'Chip', 'Arduino', 'Script'];

  @override
  Map<String, dynamic> get metadata => {'script': _script};

  late final List<CircuitPin> _pins;
  String _script = ''; // A simple assignment script, e.g., "pin2 = !pin1"

  ScriptableChip(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'IN1',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, -15),
      ),
      CircuitPin(
        id: '${id}_in2',
        name: 'IN2',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 15),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'OUT1',
        direction: PortDirection.output,
        relativePosition: Offset(halfWidth, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;
  
  @override
  void updatePropertiesFromText(String text) {
    // We could parse specific setup from text, but we'll use a dialog for the script.
    // For now, if text contains "=", we assume it's a quick inline script.
    if (text.contains('=')) {
      _script = text;
    }
  }

  @override
  void evaluate(SimulationTick tick) {
    // Very primitive script parser for demonstration
    // E.g., "OUT1 = IN1 && !IN2"
    if (_script.isEmpty) return;
    
    // Map pin states
    Map<String, bool> boolStates = {};
    for (var pin in _pins) {
      boolStates[pin.name] = pin.state.logic == LogicState.high;
    }

    try {
      final lines = _script.split(';');
      for (var line in lines) {
        if (!line.contains('=')) continue;
        
        final parts = line.split('=');
        final target = parts[0].trim();
        final expr = parts[1].trim();
        
        // Very basic hardcoded evaluation for now
        bool result = false;
        
        if (expr == 'IN1') result = boolStates['IN1'] ?? false;
        else if (expr == '!IN1') result = !(boolStates['IN1'] ?? false);
        else if (expr == 'IN2') result = boolStates['IN2'] ?? false;
        else if (expr == '!IN2') result = !(boolStates['IN2'] ?? false);
        else if (expr == 'IN1 && IN2') result = (boolStates['IN1'] ?? false) && (boolStates['IN2'] ?? false);
        else if (expr == 'IN1 || IN2') result = (boolStates['IN1'] ?? false) || (boolStates['IN2'] ?? false);
        
        // Map result back to pin
        final outPin = _pins.firstWhere((p) => p.name == target, orElse: () => _pins.first);
        if (outPin.name == target) {
          outPin.state.logic = result ? LogicState.high : LogicState.low;
          outPin.state.voltage = result ? 5.0 : 0.0;
        }
      }
    } catch (e) {
      // Ignore script errors
    }
  }

  @override
  Color getActiveColor() => Colors.teal;
}
