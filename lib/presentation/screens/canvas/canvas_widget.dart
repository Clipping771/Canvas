// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/presentation/screens/canvas/drawing_painter.dart';
import 'dart:convert';
import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:vinci_board/presentation/screens/canvas/selection_overlay.dart';
import 'package:vinci_board/presentation/widgets/weather_widget.dart';
import 'package:vinci_board/presentation/widgets/chemistry_widget.dart';
import 'package:vinci_board/presentation/screens/canvas/animated_stroke_widget.dart';
import 'package:vinci_board/engines/chemistry/chemistry_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinci_board/engines/logic/tesla_engine.dart';
import 'package:vinci_board/engines/logic/components/component_registry.dart';
import 'package:vinci_board/engines/math/ui/graph_renderer.dart';
import 'package:vinci_board/engines/math/core/graphing_engine.dart';
import 'package:vinci_board/engines/biology/ui/anatomy_viewer.dart';
import 'package:vinci_board/engines/biology/core/anatomy_simulator.dart';
import 'package:vinci_board/engines/biology/ui/cellular_visualizer.dart';
import 'package:vinci_board/engines/biology/core/cellular_simulator.dart';
import 'package:vinci_board/engines/biology/ui/genetics_visualizer.dart';
import 'package:vinci_board/engines/biology/core/genetics_simulator.dart';
import 'package:vinci_board/presentation/widgets/chemistry_lab_widget.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  final bool isEditingText;
  final VoidCallback? onTapOutsideText;
  const CanvasWidget({
    super.key,
    required this.isEditingText,
    this.onTapOutsideText,
  });

  @override
  ConsumerState<CanvasWidget> createState() => CanvasWidgetState();
}

class CanvasWidgetState extends ConsumerState<CanvasWidget>
    with SingleTickerProviderStateMixin {
  final TransformationController transformationController =
      TransformationController();

  late final AnimationController _globalAnimationController;

  Offset? _marqueeStart;
  final ValueNotifier<Rect?> _marqueeNotifier = ValueNotifier<Rect?>(null);

  @override
  void initState() {
    super.initState();
    // Start exactly in the center of the 100,000 x 100,000 canvas
    transformationController.value = Matrix4.identity()
      ..translate(-50000.0, -50000.0);

    _globalAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Do NOT call ..repeat() here. The controller is started/stopped in build()
    // based on whether any strokes actually need animation. Running it
    // unconditionally at 60fps on Windows causes the raster thread to
    // overwhelm the Win32 message queue → "Not Responding".
  }

  @override
  void dispose() {
    _globalAnimationController.dispose();
    _marqueeNotifier.dispose();
    transformationController.dispose();
    super.dispose();
  }

  /// Async-loads a ChemMolecule for a stroke that has `smiles` but no `chemMolecule`.
  /// Calls notifier to patch the stroke once data is ready.
  void _ensureMoleculeLoaded(Stroke stroke, DrawingNotifier notifier) {
    if (stroke.customMetadata?['chem_loading'] == true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.updateStrokeById(
        stroke.id,
        (s) => s.copyWith(
          customMetadata: {...(s.customMetadata ?? {}), 'chem_loading': true},
        ),
      );

      ChemistryService.fetchMolecule(stroke.smiles!).then((mol) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (mol != null) {
                notifier.updateStrokeById(
                  stroke.id,
                  (s) => s.copyWith(
                    chemMolecule: mol,
                    customMetadata: {
                      ...(s.customMetadata ?? {}),
                      'chem_loading': false,
                    },
                  ),
                );
              } else {
                notifier.updateStrokeById(
                  stroke.id,
                  (s) => s.copyWith(
                    customMetadata: {
                      ...(s.customMetadata ?? {}),
                      'chem_loading': false,
                      'chem_error': true,
                    },
                  ),
                );
              }
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawingState = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    // Only run the animation ticker when there are strokes that actually need it.
    // This prevents the 60fps raster loop from running on Windows when the canvas
    // is idle, which was causing "Not Responding" when typing in the AI chat.
    final needsAnimation = drawingState.strokes.any(
      (s) => s.animationType != null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (needsAnimation && !_globalAnimationController.isAnimating) {
        _globalAnimationController.repeat();
      } else if (!needsAnimation && _globalAnimationController.isAnimating) {
        _globalAnimationController.stop();
      }
    });

    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: drawingState.currentTool == ToolType.pan,
      scaleEnabled: drawingState.currentTool == ToolType.pan,
      minScale: 0.00001,
      maxScale: 10000.0,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPos = renderBox.globalToLocal(details.offset);
          final matrix = transformationController.value;
          final inverted = Matrix4.tryInvert(matrix);
          final canvasPosition = inverted != null
              ? MatrixUtils.transformPoint(inverted, localPos)
              : localPos;

          final toolStr = details.data.toLowerCase().replaceAll(' ', '_');

          String? widgetText;
          if (toolStr.contains('battery')) {
            widgetText = '{"type":"circuit","component":"battery"}';
          } else if (toolStr.contains('ground'))
            widgetText = '{"type":"circuit","component":"ground"}';
          else if (toolStr.contains('switch'))
            widgetText = '{"type":"circuit","component":"switch"}';
          else if (toolStr.contains('led'))
            widgetText = '{"type":"circuit","component":"led"}';
          else if (toolStr.contains('resistor'))
            widgetText = '{"type":"circuit","component":"resistor"}';
          else if (toolStr.contains('capacitor'))
            widgetText = '{"type":"circuit","component":"capacitor"}';
          else if (toolStr.contains('inductor'))
            widgetText = '{"type":"circuit","component":"inductor"}';
          else if (toolStr.contains('clock'))
            widgetText = '{"type":"circuit","component":"clock"}';
          else if (toolStr.contains('mcu'))
            widgetText = '{"type":"circuit","component":"mcu"}';
          else if (toolStr.contains('motor'))
            widgetText = '{"type":"circuit","component":"motor"}';
          else if (toolStr.contains('oscilloscope'))
            widgetText = '{"type":"circuit","component":"oscilloscope"}';
          else if (toolStr.contains('and_gate'))
            widgetText = '{"type":"circuit","component":"and"}';
          else if (toolStr.contains('or_gate'))
            widgetText = '{"type":"circuit","component":"or"}';
          else if (toolStr.contains('not_gate'))
            widgetText = '{"type":"circuit","component":"not"}';
          else if (toolStr.contains('beaker'))
            widgetText = '{"type":"beaker"}';
          else if (toolStr.contains('microscope'))
            widgetText = '{"type":"microscope"}';
          else if (toolStr.contains('cell'))
            widgetText = '{"type":"cellular"}';
          else if (toolStr.contains('genetics'))
            widgetText = '{"type":"genetics"}';
          else if (toolStr.contains('equation'))
            widgetText = '{"type":"graph","expression":"x^2"}';
          else if (toolStr.contains('anatomy'))
            widgetText = '{"type":"anatomy"}';

          if (widgetText != null) {
            final stroke = Stroke(
              points: [canvasPosition],
              color: Colors.blueAccent,
              size: 2.0,
              toolType: ToolType.widget,
              text: widgetText,
            );
            notifier.addStrokes([stroke]);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (widget.isEditingText) {
                widget.onTapOutsideText?.call();
                return;
              }
              final tapPos = details.localPosition;

              // Text tool: tap to place text at that canvas position
              if (drawingState.currentTool == ToolType.text) {
                Stroke? hitStroke;
                try {
                  hitStroke = drawingState.strokes.reversed.firstWhere(
                    (s) =>
                        s.toolType == ToolType.text &&
                        s.bounds.inflate(20).contains(tapPos),
                  );
                } catch (_) {}
                notifier.requestTextAt(tapPos, existingStroke: hitStroke);
              }
              // Pan tool: Tap to toggle switches, or probe components/wires
              else if (drawingState.currentTool == ToolType.pan) {
                Stroke? hitStroke;
                // 1. Check components
                try {
                  hitStroke = drawingState.strokes.reversed.firstWhere(
                    (s) =>
                        s.toolType != ToolType.wire &&
                        s.bounds.inflate(10).contains(tapPos),
                  );
                } catch (_) {}

                // 2. Check wires if no component hit
                if (hitStroke == null) {
                  try {
                    hitStroke = drawingState.strokes.reversed.firstWhere(
                      (s) =>
                          s.toolType == ToolType.wire &&
                          s.bounds.inflate(20).contains(tapPos),
                    );
                  } catch (_) {}
                }

                if (hitStroke != null) {
                  // If it's a switch component, toggle it
                  final comp = ComponentRegistry().createComponent(hitStroke);
                  if (comp != null && comp.name.toLowerCase() == 'switch') {
                    final currentlyOn =
                        hitStroke.customMetadata?['isOn'] == true;
                    notifier.updateStrokeById(
                      hitStroke.id,
                      (s) => s.copyWith(
                        customMetadata: {
                          ...(s.customMetadata ?? {}),
                          'isOn': !currentlyOn,
                        },
                        version: s.version + 1,
                      ),
                    );
                  } else {
                    _showProbeDialog(context, hitStroke);
                  }
                }
              }
            },
            onPanStart:
                (drawingState.currentTool == ToolType.pan ||
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
            onPanUpdate:
                (drawingState.currentTool == ToolType.pan ||
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
            onPanEnd:
                (drawingState.currentTool == ToolType.pan ||
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
                  painter: BackgroundPainter(
                    backgroundColor:
                        drawingState.canvasBackgroundColor ?? Colors.white,
                    environment: drawingState.canvasEnvironment,
                  ),
                  size: const Size(100000, 100000),
                ),
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
                    animation: _globalAnimationController,
                  ),
                  size: const Size(100000, 100000),
                ),
                ValueListenableBuilder<Stroke?>(
                  valueListenable: notifier.activeStrokeNotifier,
                  builder: (context, stroke, child) {
                    if (stroke == null) return const SizedBox.shrink();
                    return CustomPaint(
                      painter: DrawingCanvasPainter(
                        strokes: [stroke],
                        animation: _globalAnimationController,
                        useCache: false,
                      ),
                      size: const Size(100000, 100000),
                    );
                  },
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
                          child: AnimatedStrokeWidget(
                            stroke: stroke,
                            animation: _globalAnimationController,
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
                            key: ValueKey('weather_${stroke.id}'),
                            city: json['city'] ?? 'London',
                            days: safeDays,
                          );
                        } else if (type == 'graph') {
                          final expr = json['expression'] ?? 'x^2';
                          content = GraphRenderer(
                            key: ValueKey('graph_${stroke.id}'),
                            mathExpression: expr,
                            graphingEngine: GraphingEngine(),
                          );
                        } else if (type == 'anatomy') {
                          content = AnatomyViewer(
                            key: ValueKey('anatomy_${stroke.id}'),
                            simulator: AnatomySimulator(),
                          );
                        } else if (type == 'cellular') {
                          content = CellularVisualizer(
                            key: ValueKey('cellular_${stroke.id}'),
                            simulator: CellularSimulator(),
                          );
                        } else if (type == 'genetics') {
                          content = GeneticsVisualizer(
                            key: ValueKey('genetics_${stroke.id}'),
                            simulator: GeneticsSimulator(),
                          );
                        } else if (type == 'beaker') {
                          content = BeakerWidget(
                            key: ValueKey('beaker_${stroke.id}'),
                          );
                        } else if (type == 'microscope') {
                          content = MicroscopeWidget(
                            key: ValueKey('microscope_${stroke.id}'),
                          );
                        }
                      } catch (e) {
                        // ignore parsing errors
                      }

                      return Positioned(
                        key: ValueKey('pos_${stroke.id}'),
                        left: stroke.points.first.dx,
                        top: stroke.points.first.dy,
                        child: Transform.rotate(
                          angle: stroke.rotation,
                          alignment: Alignment.topLeft,
                          child: AnimatedStrokeWidget(
                            stroke: stroke,
                            animation: _globalAnimationController,
                            child: IgnorePointer(
                              ignoring:
                                  drawingState.currentTool == ToolType.select,
                              child: content,
                            ),
                          ),
                        ),
                      );
                    }),
                // Chemistry Vector Layer ÔÇö renders SMILES-based molecules natively
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
                      if (stroke.customMetadata?['chem_error'] == true) {
                        return Positioned(
                          left: stroke.points.first.dx,
                          top: stroke.points.first.dy,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.red.withValues(alpha: 0.1),
                            child: const Text(
                              'Failed to load molecule',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }
                      if (mol == null) {
                        _ensureMoleculeLoaded(stroke, notifier);
                        return Positioned(
                          left: stroke.points.first.dx,
                          top: stroke.points.first.dy,
                          child: const SizedBox(
                            width: 300,
                            height: 260,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                          ),
                        );
                      }
                      return Positioned(
                        left: stroke.points.first.dx,
                        top: stroke.points.first.dy,
                        child: IgnorePointer(
                          child:
                              stroke.animationProgress != null &&
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
                          color: Colors.blue.withValues(alpha: 0.1),
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
                    onApplyGravity: () {
                      final ids = drawingState.selectedStrokes
                          .map((s) => s.id)
                          .toList();
                      notifier.applyGravityToStrokes(ids);
                      notifier.clearSelection();
                    },
                    onStopPhysics: () {
                      notifier.stopSimulation();
                      notifier.clearSelection();
                    },
                    isPhysicsActive: drawingState.strokes.any(
                      (s) => s.physicsEnabled,
                    ),
                  ),
                if (drawingState.aiStatus != null)
                  Positioned(
                    left:
                        drawingState.aiStatusTarget?.dx ??
                        MediaQuery.of(context).size.width / 2.0 - 50,
                    top:
                        drawingState.aiStatusTarget?.dy ??
                        MediaQuery.of(context).size.height / 2.0 - 50,
                    child: AiStatusOverlay(
                      status: drawingState.aiStatus!,
                      textColor:
                          (drawingState.canvasBackgroundColor ?? Colors.white)
                                  .computeLuminance() >
                              0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProbeDialog(BuildContext context, Stroke stroke) {
    final activeComps = TeslaEngine().activeComponents;
    final comp = activeComps[stroke.id];

    String info = '';

    if (stroke.toolType == ToolType.wire) {
      // ignore: unused_local_variable
        final sourcePinId = stroke.customMetadata?['sourcePinId'] as String?;
      final targetPinId = stroke.customMetadata?['targetPinId'] as String?;

      double? v;
      if (targetPinId != null) {
        final targetCompId = stroke.customMetadata?['targetId'] as String?;
        if (targetCompId != null && activeComps.containsKey(targetCompId)) {
          final tComp = activeComps[targetCompId]!;
          try {
            final pin = tComp.pins.firstWhere((p) => p.id == targetPinId);
            v = pin.state.voltage;
          } catch (_) {}
        }
      }

      info = 'Wire\\nVoltage: ${v?.toStringAsFixed(2) ?? '0.00'} V';
    } else if (comp != null) {
      info = '${comp.name}\\n';
      if (comp.metadata.containsKey('resistance')) {
        info += 'Resistance: ${comp.metadata['resistance']} ╬®\\n';
      }
      if (comp.metadata.containsKey('voltage')) {
        info += 'Rating: ${comp.metadata['voltage']} V\\n';
      }
      for (var pin in comp.pins) {
        info += 'Pin ${pin.name}: ${pin.state.voltage.toStringAsFixed(2)} V\\n';
      }
    } else {
      info = 'Unknown Component';
    }
    final tagController = TextEditingController(
      text: stroke.semanticMeaning ?? stroke.name ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Probe Data / Tagging',
            style: TextStyle(color: Colors.blueAccent),
          ),
          backgroundColor: const Color(0xFF1E1E2C),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Component Tag / Name',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final tag = tagController.text.trim();
                ref
                    .read(drawingProvider.notifier)
                    .updateStrokeById(
                      stroke.id,
                      (s) => s.copyWith(
                        name: tag.isNotEmpty ? tag : null,
                        semanticMeaning: tag.isNotEmpty ? tag : null,
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('Save Tag'),
            ),
          ],
        );
      },
    );
  }
}

class AiStatusOverlay extends ConsumerWidget {
  final String status;
  final Color textColor;
  const AiStatusOverlay({
    super.key,
    required this.status,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
            textColor: Colors.white,
            style: GoogleFonts.nanumPenScript(
              textStyle: const TextStyle(fontSize: 28),
            ),
          ),
          const AnimatedDots(textColor: Colors.white),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (status.contains('⚠️') ||
                  status.contains('floating') ||
                  status.contains('power source')) {
                ref.read(drawingProvider.notifier).dismissWarning();
              } else {
                ref
                    .read(eventBusProvider)
                    .publish(const BaseEvent.generic('cancelGeneration'));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 16),
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
              textStyle: TextStyle(
                color: widget.textColor.withValues(alpha: 0.54),
                fontSize: 28,
              ),
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

class _AnimatedShimmerTextState extends State<AnimatedShimmerText>
    with SingleTickerProviderStateMixin {
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
        // Safe and highly performant opacity pulse effect for web & mobile
        // (replaces web-incompatible ShaderMask which causes browser tab crashes/freezes)
        final double opacity =
            0.4 + 0.5 * (1.0 + math.sin(_controller.value * 2 * math.pi));
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Text(
            widget.text,
            style: widget.style.copyWith(color: widget.textColor),
          ),
        );
      },
    );
  }
}
