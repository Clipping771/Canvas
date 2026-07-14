import 'dart:ui';

/// Defines the integration method used to step the physics simulation forward in time.
abstract class TimeIntegrator {
  /// Integrates velocity and position over time [dt].
  /// [position] is the current position.
  /// [velocity] is the current velocity.
  /// [acceleration] is the current net acceleration.
  /// Returns a tuple of (newPosition, newVelocity).
  (Offset, Offset) integrate(
    Offset position,
    Offset velocity,
    Offset acceleration,
    double dt,
  );
}

/// Semi-Implicit Euler integration. Very stable for game physics and constraints.
class SemiImplicitEulerIntegrator implements TimeIntegrator {
  @override
  (Offset, Offset) integrate(
    Offset position,
    Offset velocity,
    Offset acceleration,
    double dt,
  ) {
    // Semi-implicit euler updates velocity first, then position using the new velocity.
    final newVelocity = velocity + acceleration * dt;
    final newPosition = position + newVelocity * dt;
    return (newPosition, newVelocity);
  }
}
