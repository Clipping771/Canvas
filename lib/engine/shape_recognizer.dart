import 'dart:math';
import 'package:flutter/material.dart';

enum ShapeType { unknown, circle, star, spiral }

class ShapeRecognizer {
  static ShapeType recognize(List<Offset> points) {
    if (points.length < 20) return ShapeType.unknown; // Not enough data

    // Resample points to normalize analysis
    final resampled = _resample(points, 50);

    if (_isCircle(resampled)) return ShapeType.circle;
    if (_isStar(resampled)) return ShapeType.star;
    if (_isSpiral(resampled)) return ShapeType.spiral;

    return ShapeType.unknown;
  }

  static List<Offset> _resample(List<Offset> points, int n) {
    double pathLength = 0;
    for (int i = 1; i < points.length; i++) {
      pathLength += (points[i] - points[i - 1]).distance;
    }

    final double step = pathLength / (n - 1);
    double D = 0.0;

    List<Offset> resampled = [points.first];
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      double d = (p2 - p1).distance;
      if (D + d >= step) {
        final q = Offset(
          p1.dx + ((step - D) / d) * (p2.dx - p1.dx),
          p1.dy + ((step - D) / d) * (p2.dy - p1.dy),
        );
        resampled.add(q);
        points.insert(i, q); // insert q at i to continue from q
        D = 0.0;
      } else {
        D += d;
      }
    }
    if (resampled.length == n - 1) resampled.add(points.last);
    return resampled;
  }

  static bool _isCircle(List<Offset> points) {
    // 1. Must be closed (start and end close together)
    final distanceStartEnd = (points.first - points.last).distance;

    // Find bounding box to normalize distance threshold
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    final width = maxX - minX;
    final height = maxY - minY;
    final maxDim = max(width, height);

    // Closed check: gap < 25% of max dimension
    if (distanceStartEnd > maxDim * 0.25) return false;

    // 2. Check centroid radius variance
    final centroid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    double totalRadius = 0;
    for (var p in points) {
      totalRadius += (p - centroid).distance;
    }
    final avgRadius = totalRadius / points.length;

    double variance = 0;
    for (var p in points) {
      variance += pow((p - centroid).distance - avgRadius, 2);
    }
    final stdDev = sqrt(variance / points.length);

    // If standard deviation of radius is small compared to avgRadius (approx 80% tolerance)
    return (stdDev / avgRadius) < 0.20;
  }

  static bool _isStar(List<Offset> points) {
    // Calculate angle changes to find inflection points (corners)
    int sharpCorners = 0;
    for (int i = 2; i < points.length - 2; i++) {
      final v1 = points[i - 2] - points[i];
      final v2 = points[i + 2] - points[i];

      final angle = (atan2(v1.dy, v1.dx) - atan2(v2.dy, v2.dx)).abs();
      final normalizedAngle = angle > pi ? 2 * pi - angle : angle;

      // Star points are typically sharp angles < 60 degrees (approx 1.05 radians)
      if (normalizedAngle < 1.1) {
        sharpCorners++;
        // Skip ahead to avoid counting same corner multiple times
        i += 3;
      }
    }
    // A standard star drawn with a continuous line has 5 outer sharp corners
    return sharpCorners == 5;
  }

  static bool _isSpiral(List<Offset> points) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final centroid = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    // Check if the cumulative angle wraps around the center significantly
    double totalAngle = 0;
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1] - centroid;
      final p2 = points[i] - centroid;

      final a1 = atan2(p1.dy, p1.dx);
      final a2 = atan2(p2.dy, p2.dx);

      double diff = a2 - a1;
      if (diff > pi) diff -= 2 * pi;
      if (diff < -pi) diff += 2 * pi;

      totalAngle += diff;
    }

    // A spiral should wrap around at least 1.5 times (approx 3 * pi)
    // Also, radius should generally increase or decrease
    return totalAngle.abs() > 3 * pi;
  }

  static List<Offset> generatePerfectShape(
    ShapeType type,
    List<Offset> roughPoints,
  ) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var p in roughPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final centroid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final radius = max(maxX - minX, maxY - minY) / 2;

    List<Offset> perfect = [];

    if (type == ShapeType.circle) {
      for (int i = 0; i <= 60; i++) {
        final angle = (i / 60) * 2 * pi;
        perfect.add(
          Offset(
            centroid.dx + cos(angle) * radius,
            centroid.dy + sin(angle) * radius,
          ),
        );
      }
    } else if (type == ShapeType.star) {
      // 5-point star
      for (int i = 0; i <= 5; i++) {
        // Outer point
        final outerAngle = (i / 5) * 2 * pi - pi / 2;
        perfect.add(
          Offset(
            centroid.dx + cos(outerAngle) * radius,
            centroid.dy + sin(outerAngle) * radius,
          ),
        );

        // Inner point
        if (i < 5) {
          final innerAngle = ((i + 0.5) / 5) * 2 * pi - pi / 2;
          final innerRadius = radius * 0.4; // Star inner dip
          perfect.add(
            Offset(
              centroid.dx + cos(innerAngle) * innerRadius,
              centroid.dy + sin(innerAngle) * innerRadius,
            ),
          );
        }
      }
    } else if (type == ShapeType.spiral) {
      // Archimedean spiral
      final turns = 3;
      final maxRadius = radius;
      for (int i = 0; i <= 100; i++) {
        final t = i / 100;
        final currentAngle = t * 2 * pi * turns;
        final currentRadius = t * maxRadius;
        perfect.add(
          Offset(
            centroid.dx + cos(currentAngle) * currentRadius,
            centroid.dy + sin(currentAngle) * currentRadius,
          ),
        );
      }
    }

    return perfect;
  }
}
