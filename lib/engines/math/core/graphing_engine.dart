// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:math_expressions/math_expressions.dart';

/// Handles parsing math functions and generating data points for graphs
class GraphingEngine {
  final GrammarParser _parser = GrammarParser();
  final ContextModel _contextModel = ContextModel();

  /// Evaluates an expression (e.g. 'x^2 + 2') at a specific value of x.
  double? evaluate(String expressionStr, double xValue) {
    try {
      Expression exp = _parser.parse(expressionStr);
      _contextModel.bindVariable(Variable('x'), Number(xValue));
      return exp.evaluate(EvaluationType.REAL, _contextModel) as double;
    } catch (e) {
      // Return null if parsing or evaluation fails
      return null;
    }
  }

  /// Generates a list of points (x, y) for a given function string across an x-range.
  List<Offset> generatePoints({
    required String functionExpression,
    required double startX,
    required double endX,
    int resolution = 100, // Number of points to sample
  }) {
    List<Offset> points = [];
    if (endX <= startX || resolution <= 1) return points;

    double step = (endX - startX) / (resolution - 1);

    try {
      Expression exp = _parser.parse(functionExpression);

      for (int i = 0; i < resolution; i++) {
        double currentX = startX + (i * step);
        _contextModel.bindVariable(Variable('x'), Number(currentX));

        try {
          double currentY =
              exp.evaluate(EvaluationType.REAL, _contextModel) as double;
          // Avoid adding infinity or NaN
          if (currentY.isFinite) {
            points.add(Offset(currentX, currentY));
          }
        } catch (_) {
          // Skip point on evaluation error (e.g., division by zero)
        }
      }
    } catch (e) {
      // Parse error, return empty
    }

    return points;
  }
}
