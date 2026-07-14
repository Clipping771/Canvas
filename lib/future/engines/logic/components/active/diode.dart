import 'package:flutter/material.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';

class Diode extends CircuitComponent {
  final double forwardVoltageDrop = 0.7; // Silicon diode
  final List<CircuitPin> _pins = [];

  Diode({required String id, required super.originalStroke}) : super(id: id) {
    _pins.add(
      CircuitPin(
        id: '${id}_anode',
        name: 'anode',
        direction: PortDirection.input,
        relativePosition: const Offset(-20, 0),
      ),
    );
    _pins.add(
      CircuitPin(
        id: '${id}_cathode',
        name: 'cathode',
        direction: PortDirection.output,
        relativePosition: const Offset(20, 0),
      ),
    );
  }

  @override
  String get name => 'diode';

  @override
  List<String> get aliases => ['rectifier'];

  @override
  Map<String, dynamic> get metadata => {
    'forwardVoltageDrop': forwardVoltageDrop,
  };

  @override
  List<CircuitPin> get pins => _pins;

  @override
  Color getActiveColor() => Colors.orange;

  void evaluateLogic() {
    // Logic mostly handled by analog MNA solver
  }

  bool get isConducting {
    double vAnode = pins.firstWhere((p) => p.name == 'anode').state.voltage;
    double vCathode = pins.firstWhere((p) => p.name == 'cathode').state.voltage;
    return (vAnode - vCathode) >= forwardVoltageDrop;
  }
}
