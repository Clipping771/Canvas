import 'dart:ui';
import 'package:vinci_board/engines/physics/physics_v2/world/material.dart';

enum BodyType {
  /// Infinite mass, immovable (e.g. ground, walls).
  staticBody,

  /// Finite mass, moves according to forces.
  dynamicBody,

  /// Moves according to explicit velocities/positions, unaffected by forces (e.g. moving platforms).
  kinematicBody,
}

/// Represents a physical entity in the simulation.
class PhysicsBody {
  final String id;

  BodyType type;
  PhysicsMaterial material;

  // Linear Kinematics
  Offset position;
  Offset previousPosition; // Tracked for delta calculations in UI
  Offset velocity;
  Offset acceleration;

  // Forces
  Offset force; // Net force accumulated this step.

  // Mass properties
  double mass;
  double inverseMass;

  PhysicsBody({
    required this.id,
    this.type = BodyType.dynamicBody,
    this.material = PhysicsMaterial.rock,
    this.position = Offset.zero,
    this.velocity = Offset.zero,
    this.acceleration = Offset.zero,
    this.mass = 1.0,
  }) : previousPosition = position,
       inverseMass = (type == BodyType.staticBody || mass == 0)
           ? 0.0
           : 1.0 / mass,
       force = Offset.zero;

  /// Applies a continuous force (N) to the body's center of mass.
  void applyForce(Offset f) {
    if (type == BodyType.dynamicBody) {
      force += f;
    }
  }

  /// Applies an instantaneous impulse (N*s) to the body's center of mass, directly modifying velocity.
  void applyImpulse(Offset impulse) {
    if (type == BodyType.dynamicBody) {
      velocity += impulse * inverseMass;
    }
  }

  /// Clears forces, usually called at the end of a physics step.
  void clearForces() {
    force = Offset.zero;
  }
}
