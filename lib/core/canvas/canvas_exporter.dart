import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/presentation/screens/canvas/drawing_painter.dart';

// ---------------------------------------------------------------------------
// PNG encoding helpers — broken into yielding micro-phases so the UI never
// freezes during canvas-to-image conversion.
//
// ARCHITECTURE NOTE: ui.Canvas, ui.Picture, ui.Image are Skia/Impeller native
// objects that CANNOT be passed to a compute() isolate. The only way to keep
// the UI responsive is to yield to the event loop between the heavy phases:
//   Phase 1 → Paint all strokes onto a PictureRecorder  (CPU)
//   Phase 2 → Rasterize picture to an Image             (GPU)
//   Phase 3 → Encode Image to PNG bytes                  (CPU)
// Each phase is separated by a Future.delayed(Duration.zero) so Flutter can
// pump at least one visual frame in between.
// ---------------------------------------------------------------------------

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
      width = (canvasSize.width * pixelRatio).clamp(1.0, 4000.0).toInt();
      height = (canvasSize.height * pixelRatio).clamp(1.0, 4000.0).toInt();
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

    // ── Phase 1: Paint strokes onto a PictureRecorder (CPU-heavy) ──
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

    // Use the exact same painter as the UI to ensure 1:1 match, but bypass static cache
    final painter = DrawingCanvasPainter(strokes: strokes, useCache: false);
    painter.paint(
      canvas,
      Size(width.toDouble() / pixelRatio, height.toDouble() / pixelRatio),
    );

    canvas.restore();

    final picture = recorder.endRecording();

    // ── YIELD: Let UI pump a frame between paint and rasterize ──
    await Future.delayed(Duration.zero);

    // ── Phase 2: Rasterize to image (GPU-heavy) ──
    final img = await picture.toImage(width, height);
    picture.dispose(); // Free native memory immediately

    // ── YIELD: Let UI pump a frame between rasterize and PNG encode ──
    await Future.delayed(Duration.zero);

    // ── Phase 3: PNG encode (CPU-heavy) ──
    final pngByteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    img.dispose(); // Free native memory immediately
    if (pngByteData == null) return null;

    return pngByteData.buffer.asUint8List();
  }
}
