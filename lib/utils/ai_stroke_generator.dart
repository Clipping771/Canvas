import 'dart:math';
import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../models/tool_type.dart';

class AiStrokeGenerator {
  static Stroke generateRect(
    double x,
    double y,
    double w,
    double h,
    Color color,
    double size,
  ) {
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
    );
  }

  static Stroke generatePolygon(List<Offset> points, Color color, double size) {
    if (points.isNotEmpty && points.first != points.last) {
      points.add(points.first); // Close the polygon automatically
    }
    return Stroke(
      points: points,
      color: color,
      size: size,
      toolType: ToolType.pen,
    );
  }

  static Stroke generateCircle(
    double cx,
    double cy,
    double r,
    Color color,
    double size,
  ) {
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
    double size,
  ) {
    return Stroke(
      points: [Offset(x, y)],
      color: color,
      size: size,
      toolType: ToolType.pen,
      text: text,
    );
  }
}
