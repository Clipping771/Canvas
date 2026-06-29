import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/stroke.dart';

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

    // Draw strokes
    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.decodedImage != null) {
        final imagePaint = Paint()..filterQuality = FilterQuality.high;
        canvas.drawImage(stroke.decodedImage!, stroke.points.first, imagePaint);
        continue;
      }

      if (stroke.text != null) {
        final hasBengali = stroke.text!.codeUnits.any(
          (c) => c >= 0x0980 && c <= 0x09FF,
        );
        final baseStyle = TextStyle(color: stroke.color, fontSize: stroke.size);

        final textStyle = hasBengali
            ? GoogleFonts.galada(textStyle: baseStyle)
            : GoogleFonts.nanumPenScript(textStyle: baseStyle);

        final textSpan = TextSpan(text: stroke.text, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, stroke.points.first);
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}
