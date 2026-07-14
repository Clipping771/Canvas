import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';

class SubCircuitComponent extends CircuitComponent {
  @override
  String get name => 'IC';

  @override
  List<String> get aliases => ['IC', 'SubCircuit', 'Chip'];

  @override
  Map<String, dynamic> get metadata => {'strokes': _internalStrokesJson};

  late final List<CircuitPin> _pins;
  final String _internalStrokesJson = '[]'; // JSON serialized strokes

  SubCircuitComponent(Stroke stroke)
    : super(id: stroke.id, originalStroke: stroke) {
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    // Default pins, we would ideally parse these from the JSON
    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'IN',
        direction: PortDirection.input,
        relativePosition: Offset(-halfWidth, 0),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'OUT',
        direction: PortDirection.output,
        relativePosition: Offset(halfWidth, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void updatePropertiesFromText(String text) {
    // Maybe text sets the IC name
  }

  @override
  void applyMNA(dynamic solver) {
    // For a real sub-circuit, we would deserialize `_internalStrokesJson`,
    // run a local Node extraction, and map internal border nodes to our external pins.
    // Then stamp the internal conductance matrix into the global solver matrix.
    // For this prototype, we'll just act as a 1M ohm resistor to prevent singularities.
    solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, 1e-6);
  }

  @override
  void evaluate(SimulationTick tick) {
    // Here we would run the internal components evaluate() methods.
  }

  @override
  Color getActiveColor() => Colors.deepPurple;
}
