import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/core/mna_solver.dart';

class Inductor extends CircuitComponent {
  @override
  String get name => 'Inductor';

  @override
  List<String> get aliases => ['Inductor', 'Coil'];

  @override
  Map<String, dynamic> get metadata => {'inductance': _inductance};

  late final List<CircuitPin> _pins;
  double _inductance = 1e-3; // 1mH default

  // Inductor needs to remember its current from the previous time step
  double _previousCurrent = 0.0;

  Inductor(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
    updatePropertiesFromText(stroke.text ?? '');

    // For widget strokes (W=120, H=80, center=(60,40)):
    //   IN lead tip is at local (10,40)   → relativePosition = (-50, 0)
    //   OUT lead tip is at local (110,40) → relativePosition = (50, 0)
    bool isWidget = stroke.toolType == ToolType.widget;

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'A',
        direction: PortDirection.bidirectional,
        relativePosition: isWidget
            ? const Offset(-50, 0)
            : const Offset(-50, 0),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'B',
        direction: PortDirection.bidirectional,
        relativePosition: isWidget ? const Offset(50, 0) : const Offset(50, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void updatePropertiesFromText(String text) {
    // Parse things like 1mH, 100uH, 10H
    final RegExp regex = RegExp(
      r'([\d\.]+)\s*(m|u|n|p|k)?H',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      double val = double.tryParse(match.group(1)!) ?? 1.0;
      String? multiplier = match.group(2)?.toLowerCase();
      if (multiplier == 'm') {
        val *= 1e-3;
      } else if (multiplier == 'u')
        val *= 1e-6;
      else if (multiplier == 'n')
        val *= 1e-9;
      else if (multiplier == 'p')
        val *= 1e-12;
      else
        val *= 1e-3; // default to mH
      _inductance = val;
    }
  }

  @override
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;

    // Using Backward Euler method for Transient Analysis
    // V = L * dI/dt  =>  I(t) = I(t-1) + (dt / L) * V(t)
    // This looks like a resistor Req = L / dt in parallel with a current source Ieq = I(t-1)

    double dt = 0.016;

    double gEq = dt / _inductance;
    double iEq = _previousCurrent;

    // Stamp equivalent conductance
    solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, gEq);

    // Stamp equivalent current source
    solver.addCurrentSource(_pins[0].nodeId, _pins[1].nodeId, iEq);
  }

  @override
  void evaluate(SimulationTick tick) {
    // Update the previous current based on the newly solved voltages
    double vA = _pins[0].state.voltage;
    double vB = _pins[1].state.voltage;
    double dt = 0.016;

    // I(t) = I(t-1) + (dt / L) * (vA - vB)
    _previousCurrent = _previousCurrent + (dt / _inductance) * (vA - vB);
  }

  @override
  Color getActiveColor() => Colors.orange;
}
