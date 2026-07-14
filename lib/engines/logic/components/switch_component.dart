import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/models/logic_state.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/core/mna_solver.dart';

class SwitchComponent extends CircuitComponent {
  @override
  String get name => 'Switch';

  @override
  List<String> get aliases => ['Switch', 'Toggle'];

  @override
  Map<String, dynamic> get metadata => {};

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  SwitchComponent(Stroke stroke)
    : super(id: stroke.id, originalStroke: stroke) {
    // Read state from metadata first (set by tap-to-toggle), fallback to text
    if (stroke.customMetadata?['isOn'] == true) {
      _isOn = true;
    } else if (stroke.text != null &&
        stroke.text!.toLowerCase().contains('on')) {
      _isOn = true;
    }
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
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;
    if (_isOn) {
      // 0.001 Ohms when ON (ideal wire)
      solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, 1.0 / 0.001);
    }
  }

  @override
  void evaluate(SimulationTick tick) {
    if (_isOn) {
      _pins[1].state = _pins[0].state.copyWith();
    } else {
      _pins[1].state.logic = LogicState.floating;
      _pins[1].state.voltage = 0.0;
    }
  }

  @override
  Color getActiveColor() => _isOn ? Colors.green : Colors.grey;
}
