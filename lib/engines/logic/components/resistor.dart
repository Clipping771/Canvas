import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/models/logic_state.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/core/mna_solver.dart';

class Resistor extends CircuitComponent {
  @override
  String get name => 'Resistor';

  @override
  List<String> get aliases => ['Resistor', 'Ohm'];

  @override
  Map<String, dynamic> get metadata => {
    'resistance': _resistance,
    'maxPower': 0.25,
  };

  late final List<CircuitPin> _pins;
  double _resistance = 330.0;

  Resistor(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    updatePropertiesFromText(stroke.text ?? '');
    // For widget strokes (W=120, H=80, center=(60,40)):
    //   IN lead tip is at local (10,40)   → relativePosition = (-50, 0)
    //   OUT lead tip is at local (110,40) → relativePosition = (50, 0)
    bool isWidget = stroke.toolType == ToolType.widget;

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'IN',
        direction: PortDirection.input,
        relativePosition: isWidget
            ? const Offset(-50, 0)
            : const Offset(-50, 0),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'OUT',
        direction: PortDirection.output,
        relativePosition: isWidget ? const Offset(50, 0) : const Offset(50, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void updatePropertiesFromText(String text) {
    // Matches patterns like "220", "220Ω", "10k", "10kΩ", "1.5k"
    final RegExp regex = RegExp(
      r'([\d\.]+)\s*(k)?\s*(?:Ohm|Ω)?',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      double val = double.tryParse(match.group(1)!) ?? 330.0;
      if (match.group(2)?.toLowerCase() == 'k') {
        val *= 1000.0;
      }
      _resistance = val;
    }
  }

  @override
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;
    double conductance = isBurnedOut
        ? 1.0 / 1e9
        : 1.0 / (_resistance > 0.001 ? _resistance : 0.001);
    solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, conductance);
  }

  @override
  void evaluate(SimulationTick tick) {
    super.evaluate(tick);
    if (isBurnedOut) {
      _pins[1].state.logic = LogicState.floating;
      return;
    }

    final inputVoltage = _pins[0].state.voltage;

    if (inputVoltage > 0) {
      double outputVoltage = _pins[1].state.voltage;
      _pins[1].state.logic = outputVoltage >= 1.5
          ? LogicState.high
          : LogicState.low;
    } else {
      _pins[1].state.logic = LogicState.low;
    }
  }

  @override
  Color getActiveColor() => Colors.brown.shade400;
}
