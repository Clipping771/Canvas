import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/core/mna_solver.dart';

class LED extends CircuitComponent {
  @override
  String get name => 'LED';

  @override
  List<String> get aliases => ['LED', 'Light', 'Lamp', 'Bulb'];

  @override
  Map<String, dynamic> get metadata => {
    'forwardVoltage': 2.0,
    'resistance': 50.0,
    'maxPower': 0.1,
  };

  late final List<CircuitPin> _pins;
  bool _isOn = false;

  LED(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
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
        name: '-',
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

  @override
  bool get isActive => _isOn && !isBurnedOut;
}
