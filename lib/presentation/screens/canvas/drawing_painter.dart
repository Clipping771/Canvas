import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/core/models/canvas_environment.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:vinci_board/engines/logic/models/circuit_pin.dart';
import 'package:vinci_board/core/canvas/stroke_render_cache.dart';

class BackgroundPainter extends CustomPainter {
  final Color backgroundColor;
  final CanvasEnvironment environment;

  BackgroundPainter({required this.backgroundColor, required this.environment});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw solid background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw modern dot grid
    final double spacing = 40.0;

    // Get visible bounds
    final Rect visibleRect = canvas.getLocalClipBounds();
    if (visibleRect.isEmpty) return;

    // Determine grid line color based on background luminance
    final isDark = backgroundColor.computeLuminance() < 0.5;

    // Grid dot color
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    final dotPaint = Paint()
      ..color = dotColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double startX = (visibleRect.left / spacing).floor() * spacing;
    final double endX = (visibleRect.right / spacing).ceil() * spacing;
    final double startY = (visibleRect.top / spacing).floor() * spacing;
    final double endY = (visibleRect.bottom / spacing).ceil() * spacing;

    final List<Offset> points = [];
    for (double x = startX; x <= endX; x += spacing) {
      for (double y = startY; y <= endY; y += spacing) {
        points.add(Offset(x, y));
      }
    }

    if (points.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, points, dotPaint);
    }

    // 3. Draw a premium center coordinate axis (crosshairs)
    final centerPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    // Draw subtle vertical and horizontal lines at (50000, 50000)
    const double canvasCenter = 50000.0;
    if (visibleRect.left <= canvasCenter && visibleRect.right >= canvasCenter) {
      canvas.drawLine(
        Offset(canvasCenter, visibleRect.top),
        Offset(canvasCenter, visibleRect.bottom),
        centerPaint,
      );
    }
    if (visibleRect.top <= canvasCenter && visibleRect.bottom >= canvasCenter) {
      canvas.drawLine(
        Offset(visibleRect.left, canvasCenter),
        Offset(visibleRect.right, canvasCenter),
        centerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.environment != environment;
  }
}

class DrawingCanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Animation<double>? animation;
  final bool useCache;
  // Static cache so it survives widget rebuilds (CustomPainter is recreated on
  // every build() call, making instance-level caches useless).
  // Keyed by the identity of the last static stroke so we invalidate correctly
  // when strokes are added, removed, or modified.
  static ui.Picture? _cachedPicture;
  static int _cachedStrokeCount = -1;
  static String _cachedLastStaticStrokeId = '';
  static int _cachedTotalVersion = -1;
  final Map<String, Rect> _groupBoundsCache = {};

  DrawingCanvasPainter({required this.strokes, this.animation, this.useCache = true})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final hasEraser = strokes.any((s) => s.toolType == ToolType.eraser);
    Rect? drawingBounds;

    if (hasEraser) {
      for (final stroke in strokes) {
        if (stroke.points.isNotEmpty) {
          if (drawingBounds == null) {
            drawingBounds = stroke.bounds;
          } else {
            drawingBounds = drawingBounds.expandToInclude(stroke.bounds);
          }
        }
      }
    }

    if (hasEraser && drawingBounds != null) {
      // Inflate the bounds slightly to account for stroke width and blur
      drawingBounds = drawingBounds.inflate(50.0);
      // Wrap everything in a saveLayer so BlendMode.clear only clears strokes and not the background
      canvas.saveLayer(drawingBounds, Paint());
    }

    if (!useCache) {
      for (final stroke in strokes) {
        _drawStroke(canvas, stroke);
      }
      if (hasEraser && drawingBounds != null) {
        canvas.restore();
      }
      return;
    }

    // Separate strokes into static (can be cached) and dynamic (animated or active)
    final staticStrokes = <Stroke>[];
    final dynamicStrokes = <Stroke>[];

    for (int i = 0; i < strokes.length; i++) {
      if (i == strokes.length - 1 || strokes[i].animationType != null) {
        dynamicStrokes.add(strokes[i]);
      } else {
        staticStrokes.add(strokes[i]);
      }
    }

    final lastStaticId = staticStrokes.isNotEmpty ? staticStrokes.last.id : '';
    int totalVersionSum = 0;
    for (final s in staticStrokes) {
      totalVersionSum += s.version;
    }

    if (_cachedStrokeCount != staticStrokes.length ||
        _cachedLastStaticStrokeId != lastStaticId ||
        _cachedTotalVersion != totalVersionSum) {
      final recorder = ui.PictureRecorder();
      final cacheCanvas = Canvas(recorder);

      for (final stroke in staticStrokes) {
        _drawStroke(cacheCanvas, stroke);
      }

      _cachedPicture?.dispose(); // DISPOSE OLD PICTURE
      _cachedPicture = recorder.endRecording();
      _cachedStrokeCount = staticStrokes.length;
      _cachedLastStaticStrokeId = lastStaticId;
      _cachedTotalVersion = totalVersionSum;
    }

    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }

    for (final stroke in dynamicStrokes) {
      _drawStroke(canvas, stroke);
    }

    if (hasEraser && drawingBounds != null) {
      canvas.restore();
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    // Chemistry strokes are rendered by ChemistryWidget in canvas_widget.dart
    if (stroke.smiles != null) return;

    canvas.save();

    // Process continuous animations
    double opacityMultiplier = 1.0;
    if (stroke.animationType != null && animation != null) {
      Offset center = stroke.bounds.center;
      if (stroke.groupId != null) {
        if (!_groupBoundsCache.containsKey(stroke.groupId!)) {
          Rect? groupBounds;
          for (final s in strokes) {
            if (s.groupId == stroke.groupId) {
              groupBounds = groupBounds == null
                  ? s.bounds
                  : groupBounds.expandToInclude(s.bounds);
            }
          }
          _groupBoundsCache[stroke.groupId!] = groupBounds ?? stroke.bounds;
        }
        center = _groupBoundsCache[stroke.groupId!]!.center;
      }

      double t = animation!.value; // fallback
      if (stroke.animationProgress != null &&
          stroke.animationProgress! > 1000) {
        // We use animationProgress as a timestamp for when the animation was applied
        final elapsedMs =
            DateTime.now().millisecondsSinceEpoch - stroke.animationProgress!;
        t = (elapsedMs % 2000) / 2000.0;
      }

      canvas.translate(center.dx, center.dy);

      switch (stroke.animationType) {
        case 'pulse':
          final scale = 1.0 + 0.15 * math.sin(t * 2 * math.pi);
          canvas.scale(scale, scale);
          break;
        case 'bounce':
          final yOffset = -30.0 * math.sin(t * math.pi).abs();
          canvas.translate(0, yOffset);
          break;
        case 'spin':
          canvas.rotate(t * 2 * math.pi);
          break;
        case 'slide':
          final xOffset = 30.0 * math.sin(t * 2 * math.pi);
          canvas.translate(xOffset, 0);
          break;
        case 'shake':
          final shakeOffset = 10.0 * math.sin(t * 8 * math.pi);
          canvas.translate(shakeOffset, 0);
          break;
        case 'fade':
          opacityMultiplier = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          break;
      }

      canvas.translate(-center.dx, -center.dy);
    }

    _drawStrokeInternal(canvas, stroke, opacityMultiplier);

    canvas.restore();
  }

  void _drawStrokeInternal(
    Canvas canvas,
    Stroke stroke,
    double opacityMultiplier,
  ) {
    final isHighlighter = stroke.toolType == ToolType.highlighter;
    final isEraser = stroke.toolType == ToolType.eraser;
    final isBrush = stroke.toolType == ToolType.brush;
    final isFill = stroke.toolType == ToolType.fill;

    final paint = Paint()
      ..color = isHighlighter
          ? stroke.color.withValues(alpha: 0.4 * opacityMultiplier)
          : (isEraser
                ? Colors.white
                : stroke.color.withValues(
                    alpha: stroke.color.a * opacityMultiplier,
                  ))
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

      if (stroke.text == 'chemistry') {
        // Removes the solid white/gray background generated by PubChem API
        imagePaint.blendMode = BlendMode.multiply;
        // Increase brightness/contrast slightly so the gray (#F5F5F5) becomes pure white (#FFFFFF).
        // Pure white combined with BlendMode.multiply makes the background completely transparent!
        imagePaint.colorFilter = const ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
        ]);
      }

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

    if (stroke.toolType == ToolType.widget && stroke.text != null) {
      try {
        final data = StrokeRenderCache().getParsedJson(stroke);
        if (data != null &&
            data['action'] == 'insert_widget' &&
            data['type'] == 'weather') {
          final loc = data['location'] ?? 'Unknown';
          final temp = data['temp'] ?? '--';
          final cond = data['condition'] ?? 'Clear';
          final p = stroke.points.isNotEmpty
              ? stroke.points.first
              : Offset.zero;

          final cardRect = Rect.fromLTWH(p.dx, p.dy, 250, 120);
          final cardPaint = Paint()
            ..color = Colors.blueGrey.shade800
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

          canvas.drawRRect(
            RRect.fromRectAndRadius(cardRect, const Radius.circular(16)),
            cardPaint,
          );

          // For weather widget TextPainters, ideally they are also cached, but for now we skip caching them individually as this is an edge case.
          final tpLoc = TextPainter(
            text: TextSpan(
              text: "$loc",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tpLoc.paint(canvas, Offset(p.dx + 20, p.dy + 20));

          final tpTemp = TextPainter(
            text: TextSpan(
              text: "$temp",
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tpTemp.paint(canvas, Offset(p.dx + 20, p.dy + 55));

          final tpCond = TextPainter(
            text: TextSpan(
              text: "$cond",
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tpCond.paint(canvas, Offset(p.dx + 120, p.dy + 65));
          return;
        }
      } catch (_) {}
    }

    if (stroke.text != null && !stroke.text!.startsWith('{"type":"template"')) {
      final isCircuitWidget =
          stroke.toolType == ToolType.widget &&
          stroke.text!.contains('"type":"circuit"');

      canvas.save();
      canvas.translate(stroke.points.first.dx, stroke.points.first.dy);
      if (stroke.rotation != 0.0) {
        canvas.rotate(stroke.rotation);
      }

      if (isCircuitWidget) {
        final comp = StrokeRenderCache().getCircuitComponent(stroke);
        final compName = comp?.name.toLowerCase() ?? '';
        const double W = 120.0;
        const double H = 80.0;
        const Rect box = Rect.fromLTWH(0, 0, W, H);
        final activeColor = comp?.getActiveColor() ?? Colors.blueGrey;

        // ── Background card ──
        final bgPaint = Paint()
          ..color = const Color(0xFF1A1A2E)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(10)),
          bgPaint,
        );

        // Neon glow for active components
        if (comp != null && comp.isActive) {
          final glowPaint = Paint()
            ..color = activeColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
          canvas.drawRRect(
            RRect.fromRectAndRadius(box, const Radius.circular(10)),
            glowPaint,
          );
        }

        final borderPaint = Paint()
          ..color = activeColor.withValues(
            alpha: comp?.isActive == true ? 0.9 : 0.5,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = comp?.isActive == true ? 2.5 : 1.8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(10)),
          borderPaint,
        );

        // ── Draw component-specific schematic symbol ──
        final symPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

        if (compName == 'battery') {
          // Two vertical lines: thin (negative) and thick (positive)
          canvas.drawLine(
            const Offset(45, 25),
            const Offset(45, 55),
            symPaint..strokeWidth = 1.5,
          );
          canvas.drawLine(
            const Offset(55, 20),
            const Offset(55, 60),
            symPaint..strokeWidth = 4.0,
          );
          // Horizontal leads
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 40), const Offset(45, 40), symPaint);
          canvas.drawLine(const Offset(55, 40), const Offset(90, 40), symPaint);
          // +/- labels
          final plusSpan = TextSpan(
            text: '+',
            style: TextStyle(
              color: activeColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          );
          final minusSpan = TextSpan(
            text: '−',
            style: TextStyle(
              color: activeColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          );
          TextPainter(text: plusSpan, textDirection: TextDirection.ltr)
            ..layout()
            ..paint(canvas, const Offset(92, 32));
          TextPainter(text: minusSpan, textDirection: TextDirection.ltr)
            ..layout()
            ..paint(canvas, const Offset(2, 32));
          // Voltage label
          final v = comp?.metadata['voltage']?.toString() ?? '9';
          _drawComponentLabel(canvas, '${v}V', W, H, activeColor);
        } else if (compName == 'resistor') {
          // Zigzag pattern
          symPaint.strokeWidth = 2.5;
          final path = Path()..moveTo(10, 40);
          for (int i = 0; i < 6; i++) {
            final x1 = 20.0 + i * 12.0;
            final y1 = i.isEven ? 25.0 : 55.0;
            path.lineTo(x1, y1);
          }
          path.lineTo(92, 40);
          // Leads
          canvas.drawLine(const Offset(10, 40), const Offset(20, 40), symPaint);
          canvas.drawPath(path, symPaint);
          canvas.drawLine(
            const Offset(92, 40),
            const Offset(110, 40),
            symPaint,
          );
          // Value label
          final r = comp?.metadata['resistance'];
          String label = r != null
              ? (r >= 1000
                    ? '${(r / 1000).toStringAsFixed(1)}kΩ'
                    : '${r.toStringAsFixed(0)}Ω')
              : '330Ω';
          _drawComponentLabel(canvas, label, W, H, activeColor);
        } else if (compName == 'led') {
          // Triangle pointing right with two arrows
          final triPath = Path()
            ..moveTo(35, 20)
            ..lineTo(75, 40)
            ..lineTo(35, 60)
            ..close();
          final isOn =
              activeColor != Colors.grey && activeColor != Colors.black54;
          if (isOn) {
            // Glow effect
            final glowPaint = Paint()
              ..color = Colors.yellow.withValues(alpha: 0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
            canvas.drawCircle(const Offset(55, 40), 25, glowPaint);
          }
          canvas.drawPath(triPath, symPaint..style = PaintingStyle.stroke);
          if (isOn) {
            canvas.drawPath(
              triPath,
              Paint()
                ..color = Colors.yellow.withValues(alpha: 0.15)
                ..style = PaintingStyle.fill,
            );
          }
          // Cathode bar
          canvas.drawLine(
            const Offset(75, 20),
            const Offset(75, 60),
            symPaint..strokeWidth = 3.0,
          );
          // Leads
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 40), const Offset(35, 40), symPaint);
          canvas.drawLine(
            const Offset(75, 40),
            const Offset(110, 40),
            symPaint,
          );
          // Arrows (light emission)
          symPaint.strokeWidth = 1.5;
          canvas.drawLine(const Offset(65, 18), const Offset(72, 10), symPaint);
          canvas.drawLine(const Offset(70, 22), const Offset(77, 14), symPaint);
          _drawComponentLabel(canvas, isOn ? 'ON' : 'OFF', W, H, activeColor);
        } else if (compName == 'capacitor') {
          // Two parallel plates
          symPaint.strokeWidth = 3.0;
          canvas.drawLine(const Offset(50, 18), const Offset(50, 62), symPaint);
          canvas.drawLine(const Offset(62, 18), const Offset(62, 62), symPaint);
          // Leads
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 40), const Offset(50, 40), symPaint);
          canvas.drawLine(
            const Offset(62, 40),
            const Offset(110, 40),
            symPaint,
          );
          final c = comp?.metadata['capacitance'];
          String label = c != null
              ? '${(c * 1e6).toStringAsFixed(0)}µF'
              : '100µF';
          _drawComponentLabel(canvas, label, W, H, activeColor);
        } else if (compName == 'inductor') {
          // Coil/spring arcs
          symPaint.strokeWidth = 2.5;
          symPaint.style = PaintingStyle.stroke;
          for (int i = 0; i < 4; i++) {
            final cx = 30.0 + i * 16.0;
            canvas.drawArc(
              Rect.fromCenter(center: Offset(cx, 40), width: 16, height: 20),
              math.pi,
              -math.pi,
              false,
              symPaint,
            );
          }
          // Leads
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 40), const Offset(22, 40), symPaint);
          canvas.drawLine(
            const Offset(94, 40),
            const Offset(110, 40),
            symPaint,
          );
          final l = comp?.metadata['inductance'];
          String label = l != null
              ? '${(l * 1e3).toStringAsFixed(0)}mH'
              : '10mH';
          _drawComponentLabel(canvas, label, W, H, activeColor);
        } else if (compName == 'switch') {
          final isOn = activeColor == Colors.green;
          // Fixed contact points
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 40), const Offset(40, 40), symPaint);
          canvas.drawLine(
            const Offset(80, 40),
            const Offset(110, 40),
            symPaint,
          );
          // Contact dots
          final dotPaint = Paint()
            ..color = activeColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(const Offset(40, 40), 4, dotPaint);
          canvas.drawCircle(const Offset(80, 40), 4, dotPaint);
          // Switch arm
          if (isOn) {
            canvas.drawLine(
              const Offset(40, 40),
              const Offset(80, 40),
              symPaint..strokeWidth = 3.0,
            );
          } else {
            canvas.drawLine(
              const Offset(40, 40),
              const Offset(75, 25),
              symPaint..strokeWidth = 3.0,
            );
          }
          _drawComponentLabel(
            canvas,
            isOn ? 'CLOSED' : 'OPEN',
            W,
            H,
            activeColor,
          );
        } else if (compName == 'ground') {
          // Classic 3-descending-line ground symbol
          symPaint.strokeWidth = 2.5;
          canvas.drawLine(const Offset(60, 10), const Offset(60, 30), symPaint);
          canvas.drawLine(const Offset(35, 30), const Offset(85, 30), symPaint);
          canvas.drawLine(const Offset(42, 42), const Offset(78, 42), symPaint);
          canvas.drawLine(const Offset(50, 54), const Offset(70, 54), symPaint);
          _drawComponentLabel(canvas, 'GND', W, H, activeColor);
        } else if (compName == 'clock') {
          // Square wave
          symPaint.strokeWidth = 2.0;
          final wavePath = Path()..moveTo(20, 50);
          for (int i = 0; i < 4; i++) {
            final x = 20.0 + i * 20.0;
            wavePath.lineTo(x, 25);
            wavePath.lineTo(x + 10, 25);
            wavePath.lineTo(x + 10, 50);
            wavePath.lineTo(x + 20, 50);
          }
          canvas.drawPath(wavePath, symPaint);
          _drawComponentLabel(canvas, 'CLK', W, H, activeColor);
        } else if (compName == 'motor') {
          // Circle with M
          symPaint.strokeWidth = 2.5;
          canvas.drawCircle(const Offset(60, 38), 22, symPaint);
          // Leads
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 38), const Offset(38, 38), symPaint);
          canvas.drawLine(
            const Offset(82, 38),
            const Offset(110, 38),
            symPaint,
          );
          // M label
          final mSpan = TextSpan(
            text: 'M',
            style: TextStyle(
              color: activeColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          );
          TextPainter(text: mSpan, textDirection: TextDirection.ltr)
            ..layout()
            ..paint(canvas, const Offset(52, 26));
          _drawComponentLabel(canvas, 'Motor', W, H, activeColor);
        } else if (compName == 'oscilloscope') {
          // Mini screen
          final screenRect = RRect.fromRectAndRadius(
            const Rect.fromLTWH(15, 10, 90, 55),
            const Radius.circular(6),
          );
          canvas.drawRRect(
            screenRect,
            Paint()
              ..color = const Color(0xFF0A1F0A)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRRect(screenRect, symPaint..strokeWidth = 1.5);
          // Grid lines
          final gridPaint = Paint()
            ..color = Colors.greenAccent.withValues(alpha: 0.15)
            ..strokeWidth = 0.5;
          for (double y = 20; y < 60; y += 10) {
            canvas.drawLine(Offset(18, y), Offset(102, y), gridPaint);
          }
          for (double x = 25; x < 100; x += 15) {
            canvas.drawLine(Offset(x, 13), Offset(x, 62), gridPaint);
          }
          // Sine wave
          final wavePaint = Paint()
            ..color = Colors.greenAccent
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          final wavePath = Path()..moveTo(18, 37);
          for (double x = 18; x <= 102; x += 1) {
            wavePath.lineTo(x, 37 - 15 * math.sin((x - 18) / 84 * 4 * math.pi));
          }
          canvas.drawPath(wavePath, wavePaint);
          _drawComponentLabel(canvas, 'Scope', W, H, activeColor);
        } else if (compName.contains('and') ||
            compName.contains('or') ||
            compName.contains('not')) {
          // Logic gate body
          if (compName.contains('and')) {
            final gatePath = Path()
              ..moveTo(30, 15)
              ..lineTo(60, 15)
              ..arcToPoint(
                const Offset(60, 65),
                radius: const Radius.circular(25),
              )
              ..lineTo(30, 65)
              ..close();
            canvas.drawPath(gatePath, symPaint);
          } else if (compName.contains('not')) {
            // Triangle + bubble
            final triPath = Path()
              ..moveTo(30, 15)
              ..lineTo(75, 40)
              ..lineTo(30, 65)
              ..close();
            canvas.drawPath(triPath, symPaint);
            canvas.drawCircle(const Offset(80, 40), 5, symPaint);
          } else {
            // OR gate curved shape
            final gatePath = Path()
              ..moveTo(30, 15)
              ..quadraticBezierTo(55, 15, 80, 40)
              ..quadraticBezierTo(55, 65, 30, 65)
              ..quadraticBezierTo(45, 40, 30, 15);
            canvas.drawPath(gatePath, symPaint);
          }
          // Leads
          symPaint.strokeWidth = 2.0;
          canvas.drawLine(const Offset(10, 28), const Offset(30, 28), symPaint);
          canvas.drawLine(const Offset(10, 52), const Offset(30, 52), symPaint);
          canvas.drawLine(
            const Offset(85, 40),
            const Offset(110, 40),
            symPaint,
          );
          _drawComponentLabel(
            canvas,
            compName.contains('and')
                ? 'AND'
                : compName.contains('not')
                ? 'NOT'
                : 'OR',
            W,
            H,
            activeColor,
          );
        } else {
          // Fallback: generic chip rectangle
          final chipRect = RRect.fromRectAndRadius(
            const Rect.fromLTWH(15, 12, 90, 56),
            const Radius.circular(4),
          );
          canvas.drawRRect(chipRect, symPaint);
          // Notch
          canvas.drawArc(
            const Rect.fromLTWH(55, 8, 10, 10),
            0,
            math.pi,
            false,
            symPaint,
          );
          final nameSpan = TextSpan(
            text: comp?.name ?? 'IC',
            style: TextStyle(
              color: activeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
          TextPainter(text: nameSpan, textDirection: TextDirection.ltr)
            ..layout()
            ..paint(canvas, const Offset(40, 32));
        }
      } else if (stroke.toolType != ToolType.widget) {
        final textPainter = StrokeRenderCache().getTextPainter(stroke);
        if (textPainter != null) {
          textPainter.paint(canvas, Offset.zero);
        }
      }
      canvas.restore();

      // Draw Pins for CircuitComponents
      final comp = StrokeRenderCache().getCircuitComponent(stroke);
      if (comp != null) {
        final center = stroke.bounds.center;
        for (var pin in comp.pins) {
          final pinPos = center + pin.relativePosition;
          final isOutput = pin.direction == PortDirection.output;
          final isPowered = pin.state.voltage > 1.0;

          // Pin circle with voltage-dependent color
          final pinPaint = Paint()
            ..color = isPowered
                ? (isOutput ? Colors.orange.shade400 : Colors.amber.shade400)
                : (isOutput ? Colors.red.shade400 : Colors.blue.shade400)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pinPos, 5.0, pinPaint);

          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(pinPos, 5.0, borderPaint);

          // Pin voltage label
          if (pin.state.voltage.abs() > 0.01) {
            final vLabel = '${pin.state.voltage.toStringAsFixed(1)}V';
            final vSpan = TextSpan(
              text: vLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            );
            final vPainter = TextPainter(
              text: vSpan,
              textDirection: TextDirection.ltr,
            )..layout();

            final labelOffset =
                pinPos + Offset(-vPainter.width / 2, isOutput ? -16 : 8);

            // Draw a tiny dark badge background behind the label for perfect readability
            final badgeRect = Rect.fromLTWH(
              labelOffset.dx - 4,
              labelOffset.dy - 2,
              vPainter.width + 8,
              vPainter.height + 4,
            );
            final badgePaint = Paint()
              ..color =
                  const Color(
                    0xE01A1A2E,
                  ) // Deep elegant dark matching component card
              ..style = PaintingStyle.fill;
            canvas.drawRRect(
              RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
              badgePaint,
            );

            // Draw a subtle border for the badge matching state
            final badgeBorderPaint = Paint()
              ..color =
                  (isPowered ? Colors.orange.shade400 : Colors.blue.shade400)
                      .withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8;
            canvas.drawRRect(
              RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
              badgeBorderPaint,
            );

            vPainter.paint(canvas, labelOffset);
          }
        }

        // Draw Oscilloscope Waveform (live data from simulation)
        if (comp.name.toLowerCase() == 'oscilloscope' &&
            stroke.customMetadata?.containsKey('history') == true) {
          final history = (stroke.customMetadata!['history'] as List)
              .cast<double>();
          if (history.isNotEmpty) {
            final wavePaint = Paint()
              ..color = Colors.greenAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0;

            final path = Path();
            final rect = stroke.bounds.inflate(20);
            final startX = rect.left;
            final width = rect.width;
            final baselineY = rect.top - 20;

            for (int i = 0; i < history.length; i++) {
              final x = startX + (i / 100.0) * width;
              final y = baselineY - (history[i] * 5.0);
              if (i == 0) {
                path.moveTo(x, y);
              } else {
                path.lineTo(x, y);
              }
            }
            canvas.drawPath(path, wavePaint);
          }
        }

        // Draw Boolean Equation from Study Mode
        if (stroke.customMetadata?.containsKey('boolean_eq') == true) {
          final eq = stroke.customMetadata!['boolean_eq'] as String;
          final eqSpan = TextSpan(
            text: eq,
            style: GoogleFonts.firaCode(
              color: Colors.purpleAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          );
          final eqPainter = TextPainter(
            text: eqSpan,
            textDirection: TextDirection.ltr,
          )..layout();
          eqPainter.paint(
            canvas,
            Offset(stroke.bounds.right + 20, stroke.bounds.center.dy - 12),
          );
        }
      }
      return;
    }

    if (stroke.toolType == ToolType.portal) {
      final bounds = stroke.bounds;
      final center = bounds.center;
      // Average radius from drawn bounds
      final radius = (bounds.width + bounds.height) / 4;

      final portalPaint = Paint()
        ..color = Colors.blue.shade300.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      final glowPaint = Paint()
        ..color = Colors.indigo.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

      canvas.drawCircle(center, radius, glowPaint);
      canvas.drawCircle(center, radius, portalPaint);
      return;
    }

    if (stroke.toolType == ToolType.wire) {
      final path = stroke.path;

      // Neon glow sheath for powered active wires
      if (stroke.color == Colors.orange) {
        final glowPaint = Paint()
          ..color = Colors.orange.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.size + 6.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawPath(path, glowPaint);
      }

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

      canvas.drawPath(path, wirePaint);
      canvas.drawPath(path, corePaint);

      // Animated current flow dots along active wires
      if (stroke.color == Colors.orange &&
          animation != null &&
          path.getBounds().width > 0) {
        try {
          final ui.PathMetrics metrics = path.computeMetrics();
          final dotPaint = Paint()
            ..color = Colors.yellow.shade200
            ..style = PaintingStyle.fill;

          final double dotSpacing = 30.0;
          final double dotRadius = 2.2;

          for (final ui.PathMetric metric in metrics) {
            final double length = metric.length;
            final double offset = (animation!.value * dotSpacing) % dotSpacing;

            for (
              double distance = offset;
              distance < length;
              distance += dotSpacing
            ) {
              final tangent = metric.getTangentForOffset(distance);
              if (tangent != null) {
                canvas.drawCircle(tangent.position, dotRadius, dotPaint);
              }
            }
          }
        } catch (_) {}
      }

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
      if (!stroke.isFilled &&
          !isFill &&
          stroke.toolType == ToolType.pen &&
          stroke.points.length > 50) {
        // Massive performance gain for heavy vector loads
        final Float32List rawPoints = Float32List(stroke.points.length * 2);
        for (int i = 0; i < stroke.points.length; i++) {
          rawPoints[i * 2] = stroke.points[i].dx;
          rawPoints[i * 2 + 1] = stroke.points[i].dy;
        }
        canvas.drawRawPoints(ui.PointMode.polygon, rawPoints, paint);
      } else {
        // Draw cached path
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
  }

  /// Draw a small label below the component card
  void _drawComponentLabel(
    Canvas canvas,
    String text,
    double w,
    double h,
    Color color,
  ) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: 0.9),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - 14));
  }

  @override
  bool shouldRepaint(covariant DrawingCanvasPainter oldDelegate) {
    return true; // We can optimize this by checking if strokes changed
  }
}
