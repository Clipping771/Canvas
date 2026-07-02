import 'dart:ui';
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

  DrawingCanvasPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

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
        canvas.drawImage(stroke.decodedImage!, Offset.zero, imagePaint);
        canvas.restore();
        continue;
      }

      if (stroke.toolType == ToolType.latex) {
        // LaTeX is rendered independently via Math.tex in canvas_widget.dart,
        // so we don't paint it here on the raw canvas.
        continue;
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
        continue;
      }

      if (stroke.points.length == 1) {
        // Draw a single dot
        canvas.drawPoints(PointMode.points, [stroke.points.first], paint);
      } else {
        // Draw cached path for massive performance gain
        final path = stroke.path;
        canvas.drawPath(path, paint);

        if (stroke.isFilled && stroke.toolType == ToolType.pen) {
          final outlinePaint = Paint()
            ..color = Colors.black
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawPath(path, outlinePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingCanvasPainter oldDelegate) {
    return true; // We can optimize this by checking if strokes changed
  }
}
