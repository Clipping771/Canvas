import 'package:vinci_board/engines/math/core/symbolic_solver.dart';

/// Handles derivatives, integrals, and limits.
class CalculusEngine {
  /// Computes the symbolic derivative of an expression with respect to a variable.
  Expression differentiate(Expression expr, String respectToVar) {
    return expr.derivative(respectToVar);
  }

  /// Computes numerical integration (e.g. Riemann sum) over an interval [a, b].
  double integrateNumerically(
    Expression expr,
    String respectToVar,
    double a,
    double b, {
    int steps = 1000,
  }) {
    double sum = 0.0;
    double dx = (b - a) / steps;

    for (int i = 0; i < steps; i++) {
      double x = a + (i * dx);
      double? y = expr.evaluate({respectToVar: x});
      if (y != null) {
        sum += y * dx;
      }
    }

    return sum;
  }
}
