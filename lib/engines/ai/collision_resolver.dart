import 'dart:ui';
import 'dart:math' as math;

abstract class CollisionResolver {
  Offset resolve(Offset target, Size size, List<Rect> existingBounds);
}

class SpiralCollisionResolver implements CollisionResolver {
  final int maxAttempts;
  final double stepSize;

  SpiralCollisionResolver({this.maxAttempts = 50, this.stepSize = 40.0});

  @override
  Offset resolve(Offset target, Size size, List<Rect> existingBounds) {
    Offset currentPos = target;

    for (int i = 0; i < maxAttempts; i++) {
      Rect candidateRect = Rect.fromLTWH(
        currentPos.dx,
        currentPos.dy,
        size.width,
        size.height,
      );

      bool hasOverlap = false;
      for (var bounds in existingBounds) {
        if (candidateRect.overlaps(bounds)) {
          hasOverlap = true;
          break;
        }
      }

      if (!hasOverlap) {
        return currentPos;
      }

      // Calculate next point in Archimedean spiral
      // r = a + b * theta
      double theta = i * 0.5 * math.pi; // 90 degree steps or similar
      double radius =
          stepSize * (i / 4).ceil(); // increase radius every full turn

      currentPos = Offset(
        target.dx + radius * math.cos(theta),
        target.dy + radius * math.sin(theta),
      );
    }

    // Fallback if we hit max attempts
    return target;
  }
}
