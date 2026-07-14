import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/models/logic_state.dart';
import 'package:vinci_board/engines/logic/models/signal_state.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/core/mna_solver.dart';

class Battery extends CircuitComponent {
  @override
  String get name => 'Battery';

  @override
  List<String> get aliases => ['Battery', 'VCC', 'Power'];

  @override
  Map<String, dynamic> get metadata => {'voltage': _voltage};

  late final List<CircuitPin> _pins;
  double _voltage = 9.0;
  int? _vSourceIndex;

  Battery(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    updatePropertiesFromText(stroke.text ?? '');
    // For widget strokes (W=120, H=80, center=(60,40)):
    //   Positive lead tip is at local (90,40)  → relativePosition = (+30,  0)
    //   Negative lead tip is at local (10,40)  → relativePosition = (-50,  0)
    // For text strokes, keep the old halfWidth approach.
    bool isWidget = stroke.toolType == ToolType.widget;

    _pins = [
      CircuitPin(
        id: '${id}_out',
        name: '+',
        direction: PortDirection.output,
        relativePosition: isWidget ? const Offset(30, 0) : const Offset(50, 0),
        state: SignalState(logic: LogicState.high, voltage: _voltage),
      ),
      CircuitPin(
        id: '${id}_in',
        name: '-',
        direction: PortDirection.input,
        relativePosition: isWidget
            ? const Offset(-50, 0)
            : const Offset(-50, 0),
        state: SignalState(logic: LogicState.low, voltage: 0.0),
      ),
    ];
  }

  @override
  void updatePropertiesFromText(String text) {
    final RegExp regex = RegExp(r'(\d+(?:\.\d+)?)\s*V', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      _voltage = double.tryParse(match.group(1)!) ?? 9.0;
    }
  }

  @override
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;

    if (_vSourceIndex == null) {
      _vSourceIndex = solver.registerVoltageSource();
    } else {
      solver.addVoltageSource(
        _vSourceIndex!,
        _pins[0].nodeId,
        _pins[1].nodeId,
        _voltage,
      );
    }
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

  @override
  void resetSimulationState() {
    _vSourceIndex = null;
  }
}
