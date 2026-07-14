import 'dart:ui';
import 'package:vinci_board/engines/physics/physics_v2/world/body.dart';
import 'package:vinci_board/engines/physics/physics_v2/core/vector_math.dart';

abstract class PhysicsConstraint {
  /// Solves the constraint by applying appropriate forces or impulses to the connected bodies.
  void solve(double dt);
}

/// A Hooke's Law spring constraint connecting two bodies.
class SpringConstraint implements PhysicsConstraint {
  final PhysicsBody bodyA;
  final PhysicsBody bodyB;

  /// The rest length of the spring.
  final double restLength;

  /// The stiffness constant of the spring (k).
  final double stiffness;

  /// The damping constant to prevent infinite oscillation.
  final double damping;

  SpringConstraint({
    required this.bodyA,
    required this.bodyB,
    required this.restLength,
    this.stiffness = 50.0,
    this.damping = 5.0,
  });

  @override
  void solve(double dt) {
    if (bodyA.type == BodyType.staticBody && bodyB.type == BodyType.staticBody) {
      return;
    }

    // Calculate displacement vector from A to B
    final displacement = bodyB.position - bodyA.position;
    final currentLength = displacement.distance;

    if (currentLength == 0) return; // Prevent division by zero

    // Hooke's Law: F = -k * x
    final x = currentLength - restLength;
    final forceMagnitude = -stiffness * x;

    final direction = displacement.normalize();

    // Spring force vector (applied to B)
    Offset springForce = direction * forceMagnitude;

    // Damping force: F_d = -c * (relative velocity along spring)
    final relativeVelocity = bodyB.velocity - bodyA.velocity;
    final dampingForceMagnitude = -damping * relativeVelocity.dot(direction);
    final dampingForce = direction * dampingForceMagnitude;

    final totalForce = springForce + dampingForce;

    // Apply equal and opposite forces
    bodyB.applyForce(totalForce);
    bodyA.applyForce(-totalForce);
  }
}
