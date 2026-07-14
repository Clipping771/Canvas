import 'dart:math';

/// Solves linear and quadratic equations.
class EquationEvaluator {
  /// Solves a simple linear equation ax + b = 0
  /// Returns the root.
  double? solveLinear(double a, double b) {
    if (a == 0) return null; // No solution or infinite solutions
    return -b / a;
  }

  /// Solves a quadratic equation ax^2 + bx + c = 0
  /// Returns a list of real roots (empty if imaginary).
  List<double> solveQuadratic(double a, double b, double c) {
    if (a == 0) {
      final root = solveLinear(b, c);
      return root != null ? [root] : [];
    }

    double discriminant = (b * b) - (4 * a * c);

    if (discriminant < 0) {
      return []; // Real roots only for now
    } else if (discriminant == 0) {
      return [-b / (2 * a)];
    } else {
      double sqrtD = sqrt(discriminant);
      double root1 = (-b + sqrtD) / (2 * a);
      double root2 = (-b - sqrtD) / (2 * a);
      return [root1, root2];
    }
  }

  /// Evaluates an equation from a raw string format (e.g. "2x+5=15")
  /// Returns the step-by-step solution as a string.
  String solveEquationString(String equation) {
    // Stub for advanced equation parser
    return '1. Isolate variable\n2. Solve -> Result';
  }
}
