import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/drawing_provider.dart';
import '../models/tool_type.dart';
import '../models/stroke.dart';
import 'drawing_painter.dart';
import 'dart:convert';
import '../core/event_bus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'selection_overlay.dart';
import '../widgets/weather_widget.dart';
import '../widgets/chemistry_widget.dart';
import '../services/chemistry_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../engine/cognitive/cognitive_runtime.dart';
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

  /// Async-loads a ChemMolecule for a stroke that has `smiles` but no `chemMolecule`.
  /// Calls notifier to patch the stroke once data is ready.
  void _ensureMoleculeLoaded(Stroke stroke, DrawingNotifier notifier) {
    if (stroke.customMetadata?['chem_loading'] == true) return;
    notifier.updateStrokeById(stroke.id, (s) => s.copyWith(
      customMetadata: {...(s.customMetadata ?? {}), 'chem_loading': true},
    ));
    ChemistryService.fetchMolecule(stroke.smiles!).then((mol) {
      if (mol != null && mounted) {
        notifier.updateStrokeById(stroke.id, (s) => s.copyWith(
          chemMolecule: mol,
          customMetadata: {...(s.customMetadata ?? {}), 'chem_loading': false},
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawingState = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: drawingState.currentTool == ToolType.pan,
      scaleEnabled: true,
      minScale: 0.00001,
      maxScale: 10000.0,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: GestureDetector(
        onTapUp: (details) {
          // Text tool: tap to place text at that canvas position
          if (drawingState.currentTool == ToolType.text) {
            notifier.requestTextAt(details.localPosition);
          }
        },
        onPanStart: (drawingState.currentTool == ToolType.pan ||
                drawingState.currentTool == ToolType.text)
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
        onPanUpdate: (drawingState.currentTool == ToolType.pan ||
                drawingState.currentTool == ToolType.text)
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
        onPanEnd: (drawingState.currentTool == ToolType.pan ||
                drawingState.currentTool == ToolType.text)
            ? null
            : (details) {
                if (drawingState.currentTool == ToolType.select &&
                    _marqueeNotifier.value != null) {
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
            // Chemistry Vector Layer — renders SMILES-based molecules natively
            ...(drawingState.previewTransformedStrokes != null
                    ? drawingState.strokes.map((s) {
                        final idx = drawingState.selectedStrokes.indexOf(s);
                        return idx != -1
                            ? drawingState.previewTransformedStrokes![idx]
                            : s;
                      })
                    : drawingState.strokes)
                .where((s) => s.smiles != null && s.points.isNotEmpty)
                .map<Widget>((stroke) {
                  final mol = stroke.chemMolecule;
                  if (mol == null) {
                    _ensureMoleculeLoaded(stroke, notifier);
                    return Positioned(
                      left: stroke.points.first.dx,
                      top: stroke.points.first.dy,
                      child: const SizedBox(
                        width: 300,
                        height: 260,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 1.5)),
                      ),
                    );
                  }
                  return Positioned(
                    left: stroke.points.first.dx,
                    top: stroke.points.first.dy,
                    child: IgnorePointer(
                      child: stroke.animationProgress != null &&
                              stroke.animationProgress! < 1.0
                          ? ChemistryRevealWidget(
                              molecule: mol,
                              animationProgress: stroke.animationProgress!,
                              width: 300,
                              height: 260,
                            )
                          : ChemistryWidget(
                              molecule: mol,
                              width: 300,
                              height: 260,
                            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: textColor == Colors.black ? Colors.white : Colors.black87,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
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
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              EventBus().publish(EventType.cancelGeneration);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
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
