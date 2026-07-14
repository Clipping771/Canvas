import 'dart:ui';
import 'package:vinci_board/engines/physics/physics_v2/core/time_integrator.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/body.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/scenario.dart';
import 'package:vinci_board/engines/physics/physics_v2/core/constraint_solver.dart';

/// The global state manager for the physics simulation (Layer 2).
class SimulationWorld {
  // Layer 1 integration
  final TimeIntegrator integrator;

  // Layer 2 states
  PhysicsScenario currentScenario;
  final Map<String, PhysicsBody> _bodies = {};
  final List<PhysicsConstraint> _constraints = [];

  // Simulation metrics
  double _timeScale = 1.0;
  double? _cachedScreenHeight;

  SimulationWorld({
    TimeIntegrator? integrator,
    this.currentScenario = PhysicsScenario.earth,
  }) : integrator = integrator ?? SemiImplicitEulerIntegrator();

  /// Adds a physical body to the world.
  void addBody(PhysicsBody body) {
    _bodies[body.id] = body;
  }

  /// Removes a physical body from the world.
  void removeBody(String id) {
    _bodies.remove(id);
  }

  /// Clears all bodies and constraints from the simulation.
  void clear() {
    _bodies.clear();
    _constraints.clear();
  }

  /// Adds a physical constraint (e.g., Spring) to the world.
  void addConstraint(PhysicsConstraint constraint) {
    _constraints.add(constraint);
  }

  /// Removes a constraint.
  void removeConstraint(PhysicsConstraint constraint) {
    _constraints.remove(constraint);
  }

  /// Retrieves a body by ID.
  PhysicsBody? getBody(String id) => _bodies[id];

  /// Retrieves all bodies.
  Map<String, PhysicsBody> getAllBodies() => _bodies;

  /// Retrieves all bodies.
  Iterable<PhysicsBody> get bodies => _bodies.values;

  /// Retrieves all constraints.
  List<PhysicsConstraint> get constraints => _constraints;

  /// Changes the current environment scenario (e.g., Earth to Moon).
  void setScenario(PhysicsScenario scenario) {
    currentScenario = scenario;
    // We could trigger an event bus notification here for the UI.
  }

  /// Sets the time scale of the simulation (1.0 = real-time, 0.5 = slow mo).
  void setTimeScale(double scale) {
    _timeScale = scale;
  }

  /// Steps the simulation forward by [dt] seconds.
  void step(double dt) {
    final stepDt = dt * _timeScale;
    if (stepDt <= 0) return;

    if (_cachedScreenHeight == null) {
      double screenHeight = 800.0; // safe fallback
      try {
        final view = PlatformDispatcher.instance.views.first;
        final h = view.physicalSize.height / view.devicePixelRatio;
        if (h > 0 && !h.isNaN && !h.isInfinite) {
          screenHeight = h;
        }
      } catch (_) {}
      _cachedScreenHeight = screenHeight;
    }

    final double pixelsPerMeter = _cachedScreenHeight! / 10.0;

    // 1. Apply global fields (Gravity) and clear forces.
    for (final body in _bodies.values) {
      if (body.type == BodyType.dynamicBody) {
        // F = m*a -> F_gravity = m * g
        final gravityForce =
            (currentScenario.gravity * pixelsPerMeter) * body.mass;
        body.applyForce(gravityForce);
      }
    }

    // 1.5 Solve Constraints
    for (final constraint in _constraints) {
      constraint.solve(stepDt);
    }

    // 2. Integration
    for (final body in _bodies.values) {
      if (body.type == BodyType.dynamicBody) {
        // a = F / m
        body.acceleration = body.force * body.inverseMass;
        body.previousPosition = body.position;

        final (newPos, newVel) = integrator.integrate(
          body.position,
          body.velocity,
          body.acceleration,
          stepDt,
        );

        body.position = newPos;
        body.velocity = newVel;
      }

      // Clear forces for the next frame
      body.clearForces();
    }

    // 3. Collision Detection & Resolution (Layer 1 Integration)
    // resolveCollisions();
    // We will wire the solver from outside or inside. Actually, it's better to keep it decoupled and call it from the Adapter.
  }
}
