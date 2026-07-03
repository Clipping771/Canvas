import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../models/tool_type.dart';
import 'package:google_fonts/google_fonts.dart';

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw white background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DrawingCanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  static ui.Picture? _cachedPicture;
  static int _cachedStrokeCount = -1;

  DrawingCanvasPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = canvas.getLocalClipBounds();

    // Cache static strokes (all but the last active stroke)
    final staticCount = strokes.isNotEmpty ? strokes.length - 1 : 0;
    
    if (_cachedStrokeCount != staticCount) {
      final recorder = ui.PictureRecorder();
      final cacheCanvas = Canvas(recorder);
      
      for (int i = 0; i < staticCount; i++) {
        _drawStroke(cacheCanvas, strokes[i]);
      }
      
      _cachedPicture = recorder.endRecording();
      _cachedStrokeCount = staticCount;
    }

    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }

    // Draw active stroke with viewport culling
    if (strokes.isNotEmpty) {
      final activeStroke = strokes.last;
      if (activeStroke.bounds.overlaps(viewport)) {
        _drawStroke(canvas, activeStroke);
      }
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final isHighlighter = stroke.toolType == ToolType.highlighter;
    final isEraser = stroke.toolType == ToolType.eraser;
    final isBrush = stroke.toolType == ToolType.brush;
    final isFill = stroke.toolType == ToolType.fill;

    final paint = Paint()
      ..color = isHighlighter
          ? stroke.color.withOpacity(0.4)
          : (isEraser ? Colors.white : stroke.color)
      ..strokeWidth = isHighlighter ? stroke.size * 2 : stroke.size
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = (stroke.isFilled || isFill)
          ? PaintingStyle.fill
          : PaintingStyle.stroke;

      if (isBrush) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.size / 2);
      }

      if (isHighlighter) {
        paint.blendMode = BlendMode.multiply;
      } else if (isEraser) {
        paint.blendMode = BlendMode.clear;
      }

      if (stroke.decodedImage != null) {
        final imagePaint = Paint()..filterQuality = FilterQuality.high;
        canvas.save();
        canvas.translate(stroke.points.first.dx, stroke.points.first.dy);
        if (stroke.rotation != 0.0) {
          canvas.rotate(stroke.rotation);
        }
        if (stroke.size != 1.0) {
          canvas.scale(stroke.size, stroke.size);
        }
        
        if (stroke.animationProgress != null && stroke.animationProgress! < 1.0) {
          final progress = stroke.animationProgress!;
          final width = stroke.decodedImage!.width.toDouble();
          final height = stroke.decodedImage!.height.toDouble();
          canvas.clipRect(Rect.fromLTWH(0, 0, width * progress, height));
        }

        canvas.drawImage(stroke.decodedImage!, Offset.zero, imagePaint);
        canvas.restore();
        return;
      }

      if (stroke.toolType == ToolType.latex) {
        // LaTeX is rendered independently via Math.tex in canvas_widget.dart,
        // so we don't paint it here on the raw canvas.
        return;
      }

      if (stroke.text != null &&
          !stroke.text!.startsWith('{"type":"template"')) {
        canvas.save();
        canvas.translate(stroke.points.first.dx, stroke.points.first.dy);
        if (stroke.rotation != 0.0) {
          canvas.rotate(stroke.rotation);
        }
        final hasBengali = stroke.text!.codeUnits.any(
          (c) => c >= 0x0980 && c <= 0x09FF,
        );
        final baseStyle = TextStyle(
          color: stroke.color, 
          fontSize: stroke.size,
          height: 1.5, // Expands line height to prevent clipping tall handwriting ascenders
        );

        final textStyle = hasBengali
            ? GoogleFonts.galada(textStyle: baseStyle)
            : GoogleFonts.nanumPenScript(textStyle: baseStyle);

        final textSpan = TextSpan(text: stroke.text, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: stroke.size * 30.0); // Wrap based on font size
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
        return;
      }

      if (stroke.toolType == ToolType.portal) {
        final bounds = stroke.bounds;
        final center = bounds.center;
        // Average radius from drawn bounds
        final radius = (bounds.width + bounds.height) / 4;
        
        final portalPaint = Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        
        final glowPaint = Paint()
          ..color = Colors.cyan.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
          
        canvas.drawCircle(center, radius, glowPaint);
        canvas.drawCircle(center, radius, portalPaint);
        return;
      }

      if (stroke.toolType == ToolType.wire) {
        final wirePaint = Paint()
          ..color = stroke.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.size + 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
          
        final corePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.size / 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final path = stroke.path;
        canvas.drawPath(path, wirePaint);
        canvas.drawPath(path, corePaint);

        if (stroke.points.isNotEmpty) {
          final nodePaint = Paint()
            ..color = stroke.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(stroke.points.first, stroke.size * 2, nodePaint);
          canvas.drawCircle(stroke.points.last, stroke.size * 2, nodePaint);
        }
        return;
      }

      if (stroke.points.length == 1) {
        // Draw a single dot
        canvas.drawPoints(ui.PointMode.points, [stroke.points.first], paint);
      } else {
        // Draw cached path for massive performance gain
        final path = stroke.path;
        if (!isFill) {
          canvas.drawPath(path, paint);
        }

        if (stroke.isFilled && stroke.toolType == ToolType.pen) {
          final outlinePaint = Paint()
            ..color = Colors.black
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawPath(path, outlinePaint);
        }
      }
  }

  @override
  bool shouldRepaint(covariant DrawingCanvasPainter oldDelegate) {
    return true; // We can optimize this by checking if strokes changed
  }
}
