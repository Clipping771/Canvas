import 'package:vinci_board/engines/physics/physics_v2/world/simulation_world.dart';

/// Layer 6: Formula Engine
/// Evaluates standard kinematic and dynamic formulas based on the simulation state.
class FormulaEngine {
  final SimulationWorld world;

  FormulaEngine(this.world);

  /// Evaluates F = ma for a specific body.
  /// Returns the net force magnitude.
  double evaluateNewtonSecondLaw(String bodyId) {
    final body = world.getBody(bodyId);
    if (body == null) return 0.0;

    // F = m * a
    // Since we don't explicitly store acceleration right now,
    // we could estimate it from velocity changes, but for now we'll calculate
    // the forces acting on it from the gravity.
    final netForce = world.currentScenario.gravity * body.mass;
    return netForce.distance; // magnitude
  }

  /// Calculates kinetic energy: KE = 0.5 * m * v^2
  double calculateKineticEnergy(String bodyId) {
    final body = world.getBody(bodyId);
    if (body == null) return 0.0;

    final v = body.velocity.distance;
    return 0.5 * body.mass * (v * v);
  }

  /// Calculates potential energy (approximate based on canvas height, assuming 1000 is floor)
  /// PE = m * g * h
  double calculatePotentialEnergy(String bodyId, {double floorY = 1000.0}) {
    final body = world.getBody(bodyId);
    if (body == null) return 0.0;

    final h = (floorY - body.position.dy).clamp(0.0, double.infinity);
    final g = world.currentScenario.gravity.distance;
    return body.mass * g * h;
  }
}
