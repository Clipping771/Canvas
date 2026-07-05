import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';
import '../core/mna_solver.dart';

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
    
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = [
      CircuitPin(
        id: '${id}_in',
        name: 'A',
        direction: PortDirection.bidirectional,
        relativePosition: Offset(-halfWidth, 0),
      ),
      CircuitPin(
        id: '${id}_out',
        name: 'B',
        direction: PortDirection.bidirectional,
        relativePosition: Offset(halfWidth, 0),
      ),
    ];
  }

  @override
  List<CircuitPin> get pins => _pins;

  @override
  void updatePropertiesFromText(String text) {
    // Parse things like 10uF, 100nF, 1mF
    final RegExp regex = RegExp(r'([\d\.]+)\s*(u|n|p|m|k)?F', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      double val = double.tryParse(match.group(1)!) ?? 10.0;
      String? multiplier = match.group(2)?.toLowerCase();
      if (multiplier == 'm') val *= 1e-3;
      else if (multiplier == 'u') val *= 1e-6;
      else if (multiplier == 'n') val *= 1e-9;
      else if (multiplier == 'p') val *= 1e-12;
      else val *= 1e-6; // default to uF if just "10F" is drawn, since 10F is huge
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
    double vA_prev = _pins[0].state.voltage;
    double vB_prev = _pins[1].state.voltage;
    double vDiff_prev = vA_prev - vB_prev;
    
    double iEq = gEq * vDiff_prev;

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
