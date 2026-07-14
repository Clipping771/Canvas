import 'package:flutter/material.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';

class Transistor extends CircuitComponent {
  final String subType; // 'npn', 'pnp', 'nmos', 'pmos'
  final List<CircuitPin> _pins = [];

  Transistor({
    required String id,
    required super.originalStroke,
    this.subType = 'npn',
  }) : super(id: id) {
    if (subType.contains('mos')) {
      _pins.add(
        CircuitPin(
          id: '${id}_gate',
          name: 'gate',
          direction: PortDirection.input,
          relativePosition: const Offset(-20, 0),
        ),
      );
      _pins.add(
        CircuitPin(
          id: '${id}_drain',
          name: 'drain',
          direction: PortDirection.bidirectional,
          relativePosition: const Offset(0, -20),
        ),
      );
      _pins.add(
        CircuitPin(
          id: '${id}_source',
          name: 'source',
          direction: PortDirection.bidirectional,
          relativePosition: const Offset(0, 20),
        ),
      );
    } else {
      _pins.add(
        CircuitPin(
          id: '${id}_base',
          name: 'base',
          direction: PortDirection.input,
          relativePosition: const Offset(-20, 0),
        ),
      );
      _pins.add(
        CircuitPin(
          id: '${id}_collector',
          name: 'collector',
          direction: PortDirection.bidirectional,
          relativePosition: const Offset(0, -20),
        ),
      );
      _pins.add(
        CircuitPin(
          id: '${id}_emitter',
          name: 'emitter',
          direction: PortDirection.bidirectional,
          relativePosition: const Offset(0, 20),
        ),
      );
    }
  }

  @override
  String get name => 'transistor';

  @override
  List<String> get aliases => [subType, 'bjt', 'mosfet'];

  @override
  Map<String, dynamic> get metadata => {'subType': subType};

  @override
  List<CircuitPin> get pins => _pins;

  @override
  Color getActiveColor() => Colors.yellow;

  void evaluateLogic() {
    // Requires non-linear MNA solver using Ebers-Moll (BJT) or Level-1 MOS models.
  }
}
