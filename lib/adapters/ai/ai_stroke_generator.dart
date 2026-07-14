import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';

class AiStrokeGenerator {
  static Stroke generateRect(
    double x,
    double y,
    double w,
    double h,
    Color color,
    double size, {
    bool isFilled = false,
  }) {
    List<Offset> points = [
      Offset(x, y),
      Offset(x + w, y),
      Offset(x + w, y + h),
      Offset(x, y + h),
      Offset(x, y), // close the rect
    ];

    return Stroke(
      points: points,
      color: color,
      size: size,
      toolType: ToolType.pen,
      isFilled: isFilled,
    );
  }

  static Stroke generatePolygon(
    List<Offset> points,
    Color color,
    double size, {
    bool isFilled = false,
  }) {
    if (points.isNotEmpty && points.first != points.last) {
      points.add(points.first); // Close the polygon automatically
    }
    return Stroke(
      points: points,
      color: color,
      size: size,
      toolType: ToolType.pen,
      isFilled: isFilled,
    );
  }

  static Stroke generateCircle(
    double cx,
    double cy,
    double r,
    Color color,
    double size, {
    bool isFilled = false,
  }) {
    List<Offset> points = [];
    int segments = 36; // smooth enough
    for (int i = 0; i <= segments; i++) {
      double angle = 2 * pi * (i / segments);
      points.add(Offset(cx + r * cos(angle), cy + r * sin(angle)));
    }

    return Stroke(
      points: points,
      color: color,
      size: size,
      toolType: ToolType.pen,
      isFilled: isFilled,
    );
  }

  static Stroke generateLine(
    double x1,
    double y1,
    double x2,
    double y2,
    Color color,
    double size,
  ) {
    return Stroke(
      points: [Offset(x1, y1), Offset(x2, y2)],
      color: color,
      size: size,
      toolType: ToolType.pen,
    );
  }

  static Stroke generateText(
    String text,
    double x,
    double y,
    Color color,
    double size, {
    Map<String, dynamic>? customMetadata,
  }) {
    return Stroke(
      points: [Offset(x, y)],
      color: color,
      size: size,
      toolType: ToolType.text,
      text: text,
      customMetadata: customMetadata ?? {'isAiGenerated': true},
    );
  }

  static Stroke generateEllipse(
    double cx,
    double cy,
    double rx,
    double ry,
    Color color,
    double size, {
    bool isFilled = false,
  }) {
    List<Offset> points = [];
    int segments = 40;
    for (int i = 0; i <= segments; i++) {
      double angle = 2 * pi * (i / segments);
      points.add(Offset(cx + rx * cos(angle), cy + ry * sin(angle)));
    }
    return Stroke(
      points: points,
      color: color,
      size: size,
      toolType: ToolType.pen,
      isFilled: isFilled,
    );
  }

  static Stroke generateBezierCurve(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    Color color,
    double size,
  ) {
    List<Offset> points = [];
    int segments = 30;
    for (int i = 0; i <= segments; i++) {
      double t = i / segments;
      double u = 1.0 - t;
      double tt = t * t;
      double uu = u * u;
      double uuu = uu * u;
      double ttt = tt * t;

      double x =
          uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx;
      double y =
          uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy;
      points.add(Offset(x, y));
    }
    return Stroke(
      points: points,
      color: color,
      size: size,
      toolType: ToolType.pen,
    );
  }

  static Stroke generateOrganicPath(
    List<Offset> basePoints,
    double noiseLevel,
    Color color,
    double size, {
    bool isFilled = false,
  }) {
    if (basePoints.isEmpty) {
      return Stroke(
        points: [],
        color: color,
        size: size,
        toolType: ToolType.pen,
      );
    }
    final rand = Random();
    List<Offset> noisyPoints = [];
    for (var pt in basePoints) {
      double dx = (rand.nextDouble() * 2 - 1) * noiseLevel;
      double dy = (rand.nextDouble() * 2 - 1) * noiseLevel;
      noisyPoints.add(Offset(pt.dx + dx, pt.dy + dy));
    }
    // Close path smoothly if it's meant to be closed
    if (basePoints.first == basePoints.last && noisyPoints.length > 1) {
      noisyPoints.last = noisyPoints.first;
    }
    return Stroke(
      points: noisyPoints,
      color: color,
      size: size,
      toolType: ToolType.pen,
      isFilled: isFilled,
    );
  }
}
