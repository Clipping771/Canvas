import 'dart:ui';
import 'dart:math' as math;

/// Physics extensions for [Offset] to make it act as a full 2D Vector.
extension PhysicsVector2D on Offset {
  /// Returns the dot product of this vector and [other].
  double dot(Offset other) => dx * other.dx + dy * other.dy;

  /// Returns the 2D cross product scalar of this vector and [other].
  double cross(Offset other) => dx * other.dy - dy * other.dx;

  /// Returns a new vector representing the cross product of this scalar and vector.
  Offset crossScalar(double scalar) => Offset(-scalar * dy, scalar * dx);

  /// Returns the normalized vector. If magnitude is 0, returns zero vector.
  Offset normalize() {
    final mag = distance;
    if (mag == 0) return Offset.zero;
    return this / mag;
  }

  /// Returns the magnitude squared (length squared).
  double get distanceSquared => dx * dx + dy * dy;

  /// Returns the angle in radians of this vector.
  double get angle => math.atan2(dy, dx);

  /// Rotates the vector by [radians] around the origin.
  Offset rotate(double radians) {
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);
    return Offset(dx * cosTheta - dy * sinTheta, dx * sinTheta + dy * cosTheta);
  }
}
