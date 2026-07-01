import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/stroke.dart';
import 'drawing_painter.dart';

class CanvasExporter {
  static Future<Uint8List?> exportStrokesToImage(
    List<Stroke> strokes, {
    Size? canvasSize,
    Matrix4? transform,
    double pixelRatio = 2.0,
  }) async {
    if (strokes.isEmpty) return null;

    int width = 0;
    int height = 0;
    double offsetX = 0;
    double offsetY = 0;

    if (canvasSize != null) {
      width = (canvasSize.width * pixelRatio).toInt();
      height = (canvasSize.height * pixelRatio).toInt();
    } else {
      // Find the bounding box of the strokes to determine image size
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

      for (var stroke in strokes) {
        for (var point in stroke.points) {
          if (point.dx < minX) minX = point.dx;
          if (point.dy < minY) minY = point.dy;
          if (point.dx > maxX) maxX = point.dx;
          if (point.dy > maxY) maxY = point.dy;
        }
      }

      // Add some padding
      minX -= 20;
      minY -= 20;
      maxX += 20;
      maxY += 20;

      if (minX < 0) minX = 0;
      if (minY < 0) minY = 0;

      width = ((maxX - minX) * pixelRatio).clamp(100.0, 4000.0).toInt();
      height = ((maxY - minY) * pixelRatio).clamp(100.0, 4000.0).toInt();
      offsetX = minX;
      offsetY = minY;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill background with white
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    canvas.save();
    canvas.scale(pixelRatio, pixelRatio);
    if (transform != null) {
      canvas.transform(transform.storage);
    } else if (offsetX != 0 || offsetY != 0) {
      canvas.translate(-offsetX, -offsetY);
    }

    // Use the exact same painter as the UI to ensure 1:1 match
    final painter = DrawingCanvasPainter(strokes: strokes);
    painter.paint(canvas, Size(width.toDouble() / pixelRatio, height.toDouble() / pixelRatio));

    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}
