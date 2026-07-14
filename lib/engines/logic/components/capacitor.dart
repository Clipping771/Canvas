import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';
import 'package:vinci_board/engines/logic/core/mna_solver.dart';

class Capacitor extends CircuitComponent {
  @override
  String get name => 'Capacitor';

  @override
  List<String> get aliases => ['Capacitor', 'Cap'];

  @override
  Map<String, dynamic> get metadata => {'capacitance': _capacitance};

  late final List<CircuitPin> _pins;
  double _capacitance = 10e-6; // 10uF default

  Capacitor(Stroke stroke) : super(id: stroke.id, originalStroke: stroke) {
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
    // Parse things like 10uF, 100nF, 1mF
    final RegExp regex = RegExp(
      r'([\d\.]+)\s*(u|n|p|m|k)?F',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      double val = double.tryParse(match.group(1)!) ?? 10.0;
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
        val *= 1e-6; // default to uF if just "10F" is drawn, since 10F is huge
      _capacitance = val;
    }
  }

  @override
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver) return;

    // Using Backward Euler method for Transient Analysis
    // I = C * dV/dt  =>  I(t) = (C / dt) * (V(t) - V(t-1))
    // This looks like a resistor Req = dt / C in parallel with a current source Ieq = (C / dt) * V(t-1)

    // We assume 60 FPS -> dt = 1/60s roughly 0.016s
    double dt = 0.016;

    double gEq = _capacitance / dt;

    // Get previous voltages from pin states (preserved from last frame)
    double vaPrev = _pins[0].state.voltage;
    double vbPrev = _pins[1].state.voltage;
    double vdiffPrev = vaPrev - vbPrev;

    double iEq = gEq * vdiffPrev;

    // Stamp equivalent conductance
    solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, gEq);

    // Stamp equivalent current source (flows from A to B internally, so we add to A and subtract from B)
    // Wait, MNA addCurrentSource convention: positive current goes INTO the node.
    // If the source pushes current from B to A inside the component, it goes out of B and into A.
    // Ieq is positive if vDiff_prev > 0 (A was higher than B).
    // This means current was flowing A -> B. In the equivalent circuit, the current source pushes A -> B.
    // So it leaves A and enters B.
    solver.addCurrentSource(_pins[0].nodeId, _pins[1].nodeId, iEq);
  }

  @override
  void evaluate(SimulationTick tick) {
    // MNA handles physics
  }

  @override
  Color getActiveColor() => Colors.cyan;
}
