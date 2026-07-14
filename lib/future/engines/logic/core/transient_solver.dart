import 'package:vinci_board/engines/logic/core/mna_solver.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';

/// Handles time-dependent physics for reactive components (Capacitors, Inductors).
/// It interfaces with the MNASolver by replacing reactive components with equivalent
/// voltage/current sources based on the time step (Numerical Integration - e.g. Backward Euler).
class TransientSolver {
  final MNASolver mnaSolver;
  // ignore: unused_field
  double _currentTime = 0.0;
  double _timeStep = 0.001; // 1 ms default timestep

  TransientSolver(this.mnaSolver);

  /// Sets the simulation time step.
  void setTimeStep(double dt) {
    _timeStep = dt;
  }

  /// Advances the simulation by one time step.
  void step(List<CircuitComponent> activeComponents) {
    // 1. Pre-process reactive components (Companion Models)
    for (var comp in activeComponents) {
      if (comp.type == 'capacitor') {
        _updateCapacitorCompanion(comp);
      } else if (comp.type == 'inductor') {
        _updateInductorCompanion(comp);
      }
    }

    // 2. Solve instantaneous DC operating point using MNA
    mnaSolver.solve();

    // 3. Post-process to update component states (currents/voltages for next step)
    for (var comp in activeComponents) {
      if (comp.type == 'capacitor' || comp.type == 'inductor') {
        _saveStateHistory(comp);
      }
    }

    _currentTime += _timeStep;
  }

  void _updateCapacitorCompanion(CircuitComponent capacitor) {
    // Implement Backward Euler companion model:
    // Capacitor becomes a voltage source in series with a resistor,
    // or a current source in parallel with a resistor.
    // Req = dt / C
    // Ieq = C * V_prev / dt
  }

  void _updateInductorCompanion(CircuitComponent inductor) {
    // Implement Backward Euler companion model:
    // Req = L / dt
    // Ieq = I_prev
  }

  void _saveStateHistory(CircuitComponent comp) {
    // Read solved voltages across the component and update its internal state
    // so the next time step can calculate the proper equivalent source.
  }
}
