import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/models/logic_state.dart';
import 'package:vinci_board/engines/logic/models/signal_state.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';

class Ground extends CircuitComponent {
  @override
  String get name => 'Ground';

  @override
  List<String> get aliases => ['Ground', 'GND'];

  @override
  Map<String, dynamic> get metadata => {'voltage': 0.0};

  late final List<CircuitPin> _pins;

  Ground(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    // For widget strokes (W=120, H=80, center=(60,40)):
    //   Ground lead tip is at local (60,10) → relativePosition = (0, -30)
    bool isWidget = stroke.toolType == ToolType.widget;

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: '-',
        direction: PortDirection.input,
        relativePosition: isWidget
            ? const Offset(0, -30)
            : const Offset(-50, 0),
        state: SignalState(logic: LogicState.low, voltage: 0.0),
      ),
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
