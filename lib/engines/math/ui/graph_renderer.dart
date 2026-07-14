import 'package:flutter/material.dart';
import 'package:vinci_board/engines/math/core/graphing_engine.dart';

class GraphRenderer extends StatelessWidget {
  final String mathExpression;
  final GraphingEngine graphingEngine;

  const GraphRenderer({
    super.key,
    required this.mathExpression,
    required this.graphingEngine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _GraphPainter(
            mathExpression: mathExpression,
            graphingEngine: graphingEngine,
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final String mathExpression;
  final GraphingEngine graphingEngine;

  _GraphPainter({required this.mathExpression, required this.graphingEngine});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    // Scale defines how many pixels represent 1 unit on the graph.
    final double scale = 20.0;

    _drawGrid(canvas, size, centerX, centerY, scale);
    _drawAxes(canvas, size, centerX, centerY);
    _plotFunction(canvas, size, centerX, centerY, scale);
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    double scale,
  ) {
    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    // Vertical grid lines
    for (double i = centerX % scale; i < size.width; i += scale) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    // Horizontal grid lines
    for (double i = centerY % scale; i < size.height; i += scale) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, double centerX, double centerY) {
    final Paint axisPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;

    // X-axis
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), axisPaint);
    // Y-axis
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      axisPaint,
    );
  }

  void _plotFunction(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    double scale,
  ) {
    // Calculate the range of x-values visible on the screen
    final double minX = -centerX / scale;
    final double maxX = (size.width - centerX) / scale;

    final List<Offset> logicalPoints = graphingEngine.generatePoints(
      functionExpression: mathExpression,
      startX: minX,
      endX: maxX,
      resolution: size.width.toInt(), // 1 point per pixel for smoothness
    );

    if (logicalPoints.isEmpty) return;

    final Paint linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    bool isFirst = true;

    for (final point in logicalPoints) {
      // Map logical math coordinates to screen coordinates
      final double screenX = centerX + (point.dx * scale);
      final double screenY =
          centerY - (point.dy * scale); // Invert Y as screen Y goes down

      // Don't plot points that are wildly out of bounds to avoid rendering issues
      if (screenY.isNaN || screenY.isInfinite) continue;

      if (isFirst) {
        path.moveTo(screenX, screenY);
        isFirst = false;
      } else {
        path.lineTo(screenX, screenY);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.mathExpression != mathExpression;
  }
}
