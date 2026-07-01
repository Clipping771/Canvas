import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/drawing_provider.dart';
import '../models/tool_type.dart';
import 'drawing_painter.dart';
import 'dart:convert';
import 'package:flutter_math_fork/flutter_math.dart';
import 'selection_overlay.dart';
import '../widgets/weather_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  const CanvasWidget({super.key});

  @override
  ConsumerState<CanvasWidget> createState() => CanvasWidgetState();
}

class CanvasWidgetState extends ConsumerState<CanvasWidget> {
  final TransformationController transformationController =
      TransformationController();

  Offset? _marqueeStart;
  final ValueNotifier<Rect?> _marqueeNotifier = ValueNotifier<Rect?>(null);

  @override
  void initState() {
    super.initState();
    // Start exactly in the center of the 100,000 x 100,000 canvas
    transformationController.value = Matrix4.identity()
      ..translate(-50000.0, -50000.0);
  }

  @override
  void dispose() {
    _marqueeNotifier.dispose();
    transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawingState = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.00001, // Practically infinite zoom out
      maxScale: 10000.0, // Practically infinite zoom in
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: GestureDetector(
        onPanStart: drawingState.currentTool == ToolType.pan
            ? null
            : (details) {
                if (drawingState.currentTool == ToolType.select) {
                  _marqueeStart = details.localPosition;
                  _marqueeNotifier.value = Rect.fromPoints(
                    _marqueeStart!,
                    _marqueeStart!,
                  );
                  notifier.clearSelection();
                } else {
                  notifier.startStroke(details.localPosition);
                }
              },
        onPanUpdate: drawingState.currentTool == ToolType.pan
            ? null
            : (details) {
                if (drawingState.currentTool == ToolType.select &&
                    _marqueeStart != null) {
                  _marqueeNotifier.value = Rect.fromPoints(
                    _marqueeStart!,
                    details.localPosition,
                  );
                } else if (drawingState.currentTool != ToolType.select) {
                  notifier.updateStroke(details.localPosition);
                }
              },
        onPanEnd: drawingState.currentTool == ToolType.pan
            ? null
            : (details) {
                if (drawingState.currentTool == ToolType.select &&
                    _marqueeNotifier.value != null) {
                  // If the user just tapped (very small rect), inflate it so it selects the individual object under their finger!
                  Rect searchRect = _marqueeNotifier.value!;
                  if (searchRect.width < 10 && searchRect.height < 10) {
                    searchRect = searchRect.inflate(30);
                  }
                  notifier.selectStrokesInRect(searchRect);
                  _marqueeStart = null;
                  _marqueeNotifier.value = null;
                } else if (drawingState.currentTool != ToolType.select) {
                  notifier.endStroke();
                }
              },
        child: Stack(
          children: [
            CustomPaint(
              painter: DrawingCanvasPainter(
                strokes: drawingState.previewTransformedStrokes != null
                    ? drawingState.strokes.map((s) {
                        final idx = drawingState.selectedStrokes.indexOf(s);
                        return idx != -1
                            ? drawingState.previewTransformedStrokes![idx]
                            : s;
                      }).toList()
                    : drawingState.strokes,
              ),
              size: const Size(100000, 100000),
            ),
            // Hybrid Latex Layer
            ...(drawingState.previewTransformedStrokes != null
                    ? drawingState.strokes.map((s) {
                        final idx = drawingState.selectedStrokes.indexOf(s);
                        return idx != -1
                            ? drawingState.previewTransformedStrokes![idx]
                            : s;
                      })
                    : drawingState.strokes)
                .where(
                  (s) =>
                      s.toolType == ToolType.latex &&
                      s.text != null &&
                      s.points.isNotEmpty,
                )
                .map((stroke) {
                  return Positioned(
                    left: stroke.points.first.dx,
                    top: stroke.points.first.dy,
                    child: Transform.rotate(
                      angle: stroke.rotation,
                      alignment: Alignment.topLeft,
                      child: IgnorePointer(
                        child: Builder(
                          builder: (context) {
                            String latexStr = stroke.text!;
                            // flutter_math_fork throws CrNode errors if \\ is used outside of an environment.
                            if (latexStr.contains(r'\\') &&
                                !latexStr.contains(r'\begin')) {
                              latexStr =
                                  '\\begin{aligned}\n$latexStr\n\\end{aligned}';
                            }
                            return Math.tex(
                              latexStr,
                              textStyle: TextStyle(
                                fontSize: stroke.size,
                                color: stroke.color,
                              ),
                              onErrorFallback: (FlutterMathException e) {
                                return Text(
                                  stroke.text!,
                                  style: TextStyle(
                                    fontSize: stroke.size,
                                    color: Colors.red,
                                    fontFamily: 'monospace',
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }),
            // Native Widget Layer
            ...(drawingState.previewTransformedStrokes != null
                    ? drawingState.strokes.map((s) {
                        final idx = drawingState.selectedStrokes.indexOf(s);
                        return idx != -1
                            ? drawingState.previewTransformedStrokes![idx]
                            : s;
                      })
                    : drawingState.strokes)
                .where(
                  (s) =>
                      s.toolType == ToolType.widget &&
                      s.text != null &&
                      s.points.isNotEmpty,
                )
                .map((stroke) {
                  Widget content = const SizedBox.shrink();
                  try {
                    final json = jsonDecode(stroke.text!);
                    final type = json['type'] as String?;
                    if (type == 'weather') {
                      final int requestedDays =
                          (json['days'] as num?)?.toInt() ?? 3;
                      // Ensure we don't fetch more than 7 days
                      final safeDays = requestedDays.clamp(1, 7);
                      content = WeatherWidget(
                        city: json['city'] ?? 'London',
                        days: safeDays,
                      );
                    }
                  } catch (e) {
                    // ignore parsing errors
                  }

                  return Positioned(
                    left: stroke.points.first.dx,
                    top: stroke.points.first.dy,
                    child: Transform.rotate(
                      angle: stroke.rotation,
                      alignment: Alignment.topLeft,
                      child: IgnorePointer(child: content),
                    ),
                  );
                }),
            ValueListenableBuilder<Rect?>(
              valueListenable: _marqueeNotifier,
              builder: (context, rect, child) {
                if (rect == null) return const SizedBox.shrink();
                return Positioned.fromRect(
                  rect: rect,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.blue,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (drawingState.selectionBounds != null)
              TransformSelectionOverlay(
                bounds: drawingState.selectionBounds!,
                transformationController: transformationController,
                onTransform: (dx, dy, scale, rotation) {
                  notifier.transformSelection(dx, dy, scale, rotation);
                },
                onTransformEnd: () {
                  notifier.commitSelectionTransform();
                },
                onDuplicate: () {
                  notifier.duplicateSelection();
                },
                onDelete: () {
                  notifier.deleteSelection();
                },
                onDeselect: () {
                  notifier.clearSelection();
                },
              ),
            if (drawingState.aiStatus != null && drawingState.aiStatusTarget != null)
              Positioned(
                left: drawingState.aiStatusTarget!.dx,
                top: drawingState.aiStatusTarget!.dy,
                child: AiStatusOverlay(
                  status: drawingState.aiStatus!, 
                  textColor: (drawingState.canvasBackgroundColor ?? Colors.white).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AiStatusOverlay extends StatelessWidget {
  final String status;
  final Color textColor;
  const AiStatusOverlay({super.key, required this.status, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedShimmerText(
          text: status,
          textColor: textColor,
          style: GoogleFonts.nanumPenScript(
            textStyle: const TextStyle(fontSize: 28),
          ),
        ),
        AnimatedDots(textColor: textColor),
      ],
    );
  }
}

class AnimatedDots extends StatefulWidget {
  final Color textColor;
  const AnimatedDots({super.key, required this.textColor});

  @override
  AnimatedDotsState createState() => AnimatedDotsState();
}

class AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        String dots = "";
        if (_controller.value > 0.75) {
          dots = "...";
        } else if (_controller.value > 0.5) {
          dots = "..";
        } else if (_controller.value > 0.25) {
          dots = ".";
        }

        return SizedBox(
          width: 30,
          child: Text(
            dots,
            style: GoogleFonts.nanumPenScript(
              textStyle: TextStyle(color: widget.textColor.withOpacity(0.54), fontSize: 28),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color textColor;
  
  const AnimatedShimmerText({
    super.key, 
    required this.text,
    required this.style,
    required this.textColor,
  });

  @override
  State<AnimatedShimmerText> createState() => _AnimatedShimmerTextState();
}

class _AnimatedShimmerTextState extends State<AnimatedShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.textColor.withOpacity(0.38),
                widget.textColor.withOpacity(0.87),
                widget.textColor.withOpacity(0.38),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: const Alignment(-1.0, -0.5),
              end: const Alignment(2.0, 0.5),
              transform: GradientRotation(_controller.value * 2 * 3.14159),
            ).createShader(bounds);
          },
          child: Text(
            widget.text, 
            style: widget.style.copyWith(color: widget.textColor),
          ),
        );
      },
    );
  }
}
