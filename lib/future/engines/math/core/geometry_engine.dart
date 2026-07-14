import 'dart:math';
import 'dart:ui';

/// Analyzes drawn points to determine geometry shapes and calculate properties
class GeometryEngine {
  /// Calculates the distance between two points
  static double distance(Offset p1, Offset p2) {
    return sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2));
  }

  /// Calculates the perimeter of a polygon defined by a list of points
  static double calculatePerimeter(List<Offset> points) {
    if (points.length < 2) return 0.0;
    double perimeter = 0.0;
    for (int i = 0; i < points.length; i++) {
      int next = (i + 1) % points.length;
      perimeter += distance(points[i], points[next]);
    }
    return perimeter;
  }

  /// Calculates the area of a polygon using the Shoelace formula
  static double calculateArea(List<Offset> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += points[i].dx * points[j].dy;
      area -= points[j].dx * points[i].dy;
    }
    return (area.abs() / 2.0);
  }

  /// Calculates the interior angle at point B given A-B-C
  static double calculateAngle(Offset a, Offset b, Offset c) {
    double ab = distance(a, b);
    double bc = distance(b, c);
    double ac = distance(a, c);

    if (ab == 0 || bc == 0) return 0.0;

    double cosB = (ab * ab + bc * bc - ac * ac) / (2 * ab * bc);
    // Clamp to handle potential floating point inaccuracies
    cosB = cosB.clamp(-1.0, 1.0);
    return acos(cosB) * (180 / pi); // Return in degrees
  }

  /// Attempts to classify a shape based on its points
  static String classifyShape(List<Offset> points) {
    if (points.length < 3) return 'Line/Curve';

    if (points.length == 3) return 'Triangle';
    if (points.length == 4) return 'Quadrilateral';

    if (points.length > 8 && _isCircular(points)) {
      return 'Circle';
    }

    return 'Polygon (${points.length} sides)';
  }

  static bool _isCircular(List<Offset> points) {
    if (points.isEmpty) return false;

    // Find centroid
    double sumX = 0, sumY = 0;
    for (var p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    Offset centroid = Offset(sumX / points.length, sumY / points.length);

    // Calculate distances to centroid
    List<double> distances = points.map((p) => distance(p, centroid)).toList();

    double avgDistance = distances.reduce((a, b) => a + b) / distances.length;

    // Calculate variance
    double variance = 0;
    for (var d in distances) {
      variance += pow(d - avgDistance, 2);
    }
    variance /= distances.length;

    // If standard deviation is small relative to average radius, it's likely a circle
    double stdDev = sqrt(variance);
    return stdDev < (avgDistance * 0.15); // 15% tolerance
  }
}
