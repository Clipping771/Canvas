// ignore_for_file: unused_field, unused_element, unused_local_variable, empty_statements
// ignore_for_file: deprecated_member_use
import 'package:vinci_board/presentation/providers/ai_execution_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:vinci_board/core/models/easter_egg_mode.dart';
import 'package:vinci_board/core/models/canvas_environment.dart';
import 'package:vinci_board/presentation/screens/canvas/canvas_widget.dart';
import 'package:vinci_board/engines/cognitive/cognitive_runtime.dart';
import 'package:vinci_board/engines/logic/tesla_engine.dart';
import 'package:vinci_board/engines/physics/particle_engine.dart';
import 'package:vinci_board/engines/physics/physics_engine.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/scenario.dart';
import 'package:vinci_board/engines/physics/physics_v2/tools/physics_hud.dart';
import 'package:vinci_board/engines/physics/physics_v2/tools/physics_exam_overlay.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/presentation/providers/canvas_provider.dart';
import 'package:vinci_board/presentation/providers/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:vinci_board/presentation/widgets/achievements_dialog.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/core/models/app_canvas.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/adapters/export/plantuml_service.dart';

import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';
import 'package:vinci_board/presentation/widgets/quiz_overlay.dart';
import 'package:vinci_board/core/canvas/semantic_camera.dart';
import 'package:vinci_board/adapters/ai/ai_stroke_generator.dart';
import 'package:vinci_board/core/theme/da_vinci_theme.dart';
import 'package:vinci_board/presentation/screens/components/component_drawer.dart';
import 'package:vinci_board/presentation/screens/components/properties_inspector.dart';
import 'package:vinci_board/engines/chemistry/chemistry_service.dart';
import 'package:vinci_board/adapters/storage/cloud_sync_service.dart';
import 'package:vinci_board/adapters/export/export_service.dart';
import 'package:vinci_board/engines/monetization/monetization_service.dart';
import 'package:vinci_board/presentation/providers/lms_provider.dart';
import 'package:vinci_board/presentation/screens/dashboard/teacher_dashboard_screen.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  final String canvasId;

  const CanvasScreen({super.key, required this.canvasId});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with TickerProviderStateMixin {
  late final String _currentCanvasId = widget.canvasId;
  bool _isChatOpen = false;
  bool _showToolbox = true;
  bool _showExamMode = false;
  bool _isComponentDrawerOpen = false;
  Map<String, dynamic>? _selectedComponentData;
  final GlobalKey<CanvasWidgetState> _canvasKey =
      GlobalKey<CanvasWidgetState>();
  final FocusNode _canvasFocusNode = FocusNode();

  Offset? _editingPosition;
  Stroke? _editingStroke;
  final TextEditingController _editingController = TextEditingController();
  final FocusNode _editingFocusNode = FocusNode();

  bool get isInlineEditing => _editingPosition != null;

  void _startInlineEditing(Offset pos, [Stroke? stroke]) {
    setState(() {
      _editingPosition = pos;
      _editingStroke = stroke;
      _editingController.text = stroke?.text ?? '';
    });
    _editingFocusNode.requestFocus();
  }

  void _stopInlineEditing({bool askAi = false}) {
    if (_editingPosition == null) return;
    final text = _editingController.text.trim();
    final pos = _editingPosition!;
    final stroke = _editingStroke;

    setState(() {
      _editingPosition = null;
      _editingStroke = null;
      _editingController.clear();
    });

    if (text.isNotEmpty) {
      if (askAi) {
        String? strokeId;
        if (stroke == null) {
          strokeId = ref.read(drawingProvider.notifier).placeText(text, pos);
        } else {
          ref.read(drawingProvider.notifier).updateStrokeById(stroke.id, (s) => s.copyWith(text: text, version: s.version + 1));
          strokeId = stroke.id;
        }

        final screenSize = MediaQuery.of(context).size;
        final canvasTransform = _canvasKey.currentState?.transformationController.value ?? Matrix4.identity();
        ref.read(aiExecutionProvider).askAi(
          prompt: text,
          promptCanvasPosition: pos,
          promptStrokeId: strokeId,
          screenSize: screenSize,
          canvasTransform: canvasTransform,
        );
      } else {
        if (stroke == null) {
          ref.read(drawingProvider.notifier).placeText(text, pos);
        } else {
          ref.read(drawingProvider.notifier).updateStrokeById(stroke.id, (s) => s.copyWith(text: text, version: s.version + 1));
        }
      }
    } else if (stroke != null) {
      ref.read(drawingProvider.notifier).deleteStroke(stroke.id);
    }
  }

  AnimationController? _cameraController;
  Animation<Matrix4>? _cameraAnimation;
  void _confirmClearCanvas() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Canvas?'),
        content: const Text(
          'Are you sure you want to delete everything? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(drawingProvider.notifier).clearCanvas();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _focusOnTarget(
    Offset targetCenter, {
    CameraIntent intent = CameraIntent.hardFocus,
    String? trackingStrokeId,
  }) {
    if (_canvasKey.currentState == null) return;

    final size = MediaQuery.of(context).size;
    final controller = _canvasKey.currentState!.transformationController;
    final currentMatrix = controller.value;

    final targetScale = currentMatrix.getMaxScaleOnAxis();

    final chatPanelWidth = _isChatOpen ? 400.0 : 0.0;
    final availableWidth = size.width - chatPanelWidth;

    final targetX = (availableWidth / 2) - (targetCenter.dx * targetScale);
    final targetY = (size.height / 2) - (targetCenter.dy * targetScale);

    final initialTargetMatrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(targetScale);

    _cameraController?.dispose();

    int durationMs = 600;
    if (intent == CameraIntent.softGuide) durationMs = 1500;
    if (intent == CameraIntent.userAssistedFocus) durationMs = 1000;

    _cameraController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    final curvedAnim = CurvedAnimation(
      parent: _cameraController!,
      curve: intent == CameraIntent.softGuide
          ? Curves.easeOutCubic
          : Curves.easeInOut,
    );

    curvedAnim.addListener(() {
      Matrix4 dynamicTarget = initialTargetMatrix;

      if (trackingStrokeId != null) {
        try {
          final strokes = ref.read(drawingProvider).strokes;
          final stroke = strokes.firstWhere((s) => s.id == trackingStrokeId);
          final tCenter = stroke.bounds.center;
          final tX = (availableWidth / 2) - (tCenter.dx * targetScale);
          final tY = (size.height / 2) - (tCenter.dy * targetScale);
          dynamicTarget = Matrix4.identity()
            ..translate(tX, tY)
            ..scale(targetScale);
        } catch (_) {}
      }

      controller.value = Matrix4Tween(
        begin: currentMatrix,
        end: dynamicTarget,
      ).transform(curvedAnim.value);
    });

    _cameraController!.forward();
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  StreamSubscription? _quizSub;
  StreamSubscription? _aiTaskSub;

  late final DrawingNotifier _drawingNotifier;

  @override
  void initState() {
    super.initState();
    _editingFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              _editingFocusNode.unfocus();
              setState(() {
                _editingPosition = null;
                _editingStroke = null;
                _editingController.clear();
              });
            }
          });
          return KeyEventResult.ignored; // Let the OS finish the keystroke
        }
        final isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
        if (event.logicalKey == LogicalKeyboardKey.enter && isShift) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              _editingFocusNode.unfocus();
              _stopInlineEditing(askAi: true);
            }
          });
          return KeyEventResult.ignored; // Let the OS finish the keystroke to avoid IME deadlocks
        }
      }
      return KeyEventResult.ignored;
    };

    _drawingNotifier = ref.read(drawingProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPageStrokes();
      _drawingNotifier.textInsertRequest.addListener(_onTextInsertRequest);
    });
    _quizSub = ref
        .read(eventBusProvider)
        .stream
        .where(
          (e) => e is GenericEvent && e.type == EventTypes.aiActionDispatched,
        )
        .listen(_handleQuizEvent);
    _aiTaskSub = ref
        .read(eventBusProvider)
        .stream
        .where((e) => e is GenericEvent && e.type == EventTypes.aiTaskCompleted)
        .listen(_handleAiTaskCompleted);
    CognitiveRuntime().initialize();
    ChemistryService.initializeEngine();
  }

  @override
  void dispose() {
    _drawingNotifier.textInsertRequest.removeListener(_onTextInsertRequest);
    _quizSub?.cancel();
    _aiTaskSub?.cancel();
    CognitiveRuntime().shutdown();
    _cameraController?.dispose();
    _canvasFocusNode.dispose();
    _editingController.dispose();
    _editingFocusNode.dispose();
    super.dispose();
  }

  void _onTextInsertRequest() {
    final req = ref.read(drawingProvider.notifier).textInsertRequest.value;
    if (req == null) return;
    // Reset so the listener doesn't fire again immediately
    ref.read(drawingProvider.notifier).textInsertRequest.value = null;

    final Offset pos = req['position'];
    final Stroke? existingStroke = req['stroke'];
    _startInlineEditing(pos, existingStroke);
  }

  void _handleAiTaskCompleted(BaseEvent event) {
    if (_canvasKey.currentState == null) return;

    final payload =
        (event is GenericEvent ? event.payload : null) as Map<String, dynamic>?;
    final intent = payload?['intent'] as CameraIntent?;
    final targetStrokeId = payload?['targetStrokeId'] as String?;

    if (intent == CameraIntent.noAction) return;

    Offset? targetCenter;

    if (targetStrokeId != null) {
      try {
        targetCenter = ref
            .read(drawingProvider)
            .strokes
            .firstWhere((s) => s.id == targetStrokeId)
            .bounds
            .center;
      } catch (_) {}
    }

    if (targetCenter == null) {
      final bounds = ref.read(drawingProvider).lastAddedBounds;
      if (bounds == null) return;
      targetCenter = bounds.center;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusOnTarget(
          targetCenter!,
          intent: intent ?? CameraIntent.hardFocus,
          trackingStrokeId: targetStrokeId,
        );
      }
    });
  }

  void _handleQuizEvent(BaseEvent event) {
    final payload =
        (event is GenericEvent ? event.payload : null) as Map<String, dynamic>?;
    if (payload?['action'] == 'trigger_quiz') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => QuizOverlay(
          quizData: payload ?? {},
          onComplete: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  void _loadPageStrokes() {
    try {
      final canvases = ref.read(canvasProvider);
      final page = canvases.firstWhere((c) => c.id == _currentCanvasId);
      ref.read(drawingProvider.notifier).loadStrokes(page.strokes);

      if (page.strokes.isNotEmpty) {
        Rect? bounds;
        for (final s in page.strokes) {
          if (s.points.isNotEmpty) {
            bounds = bounds == null
                ? s.bounds
                : bounds.expandToInclude(s.bounds);
          }
        }
        if (bounds != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _focusOnTarget(bounds!.center, intent: CameraIntent.hardFocus);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load strokes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen(drawingProvider) removed to prevent 60fps QuadTree churn during dragging.
    // Spatial rebuild is now manually triggered in DrawingProvider (endStroke, loadStrokes, etc).
    final drawingState = ref.watch(drawingProvider);
    if (drawingState.currentTool != ToolType.text && _editingPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editingPosition != null) {
          _stopInlineEditing();
        }
      });
    }

    final canvases = ref.watch(canvasProvider);
    final canvasIndex = canvases.indexWhere((c) => c.id == _currentCanvasId);
    if (canvasIndex == -1) {
      return const Scaffold(body: Center(child: Text('Canvas not found')));
    }
    final page = canvases[canvasIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        flexibleSpace: ClipRect(
          child: kIsWeb
              ? Container(color: Colors.white.withValues(alpha: 0.85))
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.transparent),
                ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => _saveAndExit(),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF).withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.back,
                color: Color(0xFF3D5AFE),
                size: 18,
              ),
            ),
          ),
        ),
        title: Text(
          page.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () => _showCanvasMenu(ctx, page),
            ),
          ),
        ],
      ),
      body: Focus(
        focusNode: _canvasFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (!_canvasFocusNode.hasPrimaryFocus) return KeyEventResult.ignored;
          if (!ref.read(settingsProvider).enableKeyboardShortcuts) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent) {
            final isCtrl =
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.controlLeft,
                ) ||
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.controlRight,
                ) ||
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.metaLeft,
                ) ||
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.metaRight,
                );
            final isShift =
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.shiftLeft,
                ) ||
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.shiftRight,
                );

            if (isCtrl) {
              if (event.logicalKey == LogicalKeyboardKey.keyC) {
                ref.read(drawingProvider.notifier).copySelection();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyX) {
                ref.read(drawingProvider.notifier).cutSelection();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
                ref.read(drawingProvider.notifier).duplicateSelection();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
                ref.read(drawingProvider.notifier).selectAll();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyZ) {
                if (isShift) {
                  ref.read(drawingProvider.notifier).redo();
                } else {
                  ref.read(drawingProvider.notifier).undo();
                }
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
                ref.read(drawingProvider.notifier).redo();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
                final pasted = ref
                    .read(drawingProvider.notifier)
                    .pasteFromClipboard();
                if (!pasted) {
                  _pasteSystemClipboard();
                }
                return KeyEventResult.handled;
              }
            } else {
              if (event.logicalKey == LogicalKeyboardKey.delete ||
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                if (FocusManager.instance.primaryFocus != node) {
                  return KeyEventResult.ignored;
                }
                ref.read(drawingProvider.notifier).deleteSelection();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                // To deselect, we can call a method or just trigger empty selectStrokesInRect
                ref
                    .read(drawingProvider.notifier)
                    .selectStrokesInRect(Rect.zero);
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // Infinite Dynamic Background
            Container(
              color:
                  ref.watch(drawingProvider).canvasBackgroundColor ??
                  AppColors.background,
            ),
            // Environment Background
            AnimatedContainer(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              color:
                  ref.watch(drawingProvider).canvasEnvironment ==
                      CanvasEnvironment.warm
                  ? Colors.orange.withValues(alpha: 0.15)
                  : (ref.watch(drawingProvider).canvasEnvironment ==
                            CanvasEnvironment.frozen
                        ? Colors.blue.withValues(alpha: 0.05)
                        : Colors.transparent),
            ),
            Listener(
              onPointerDown: (_) {
                if (ref.read(drawingProvider).currentTool == ToolType.text) {
                   return; // Do not request canvas focus if we are using the text tool
                }
                if (isInlineEditing) {
                   return; // Do not steal focus if inline text editor is active
                }
                if (!_canvasFocusNode.hasPrimaryFocus) {
                  _canvasFocusNode.requestFocus();
                }
              },
              child: CanvasWidget(
                key: _canvasKey,
                isEditingText: _editingPosition != null,
                onTapOutsideText: _stopInlineEditing,
              ),
            ),
            if (_editingPosition != null) _buildInlineEditor(),
            if (ref.watch(drawingProvider).showGoldenRatio)
              const Positioned.fill(child: GoldenRatioOverlay()),
            // Environment Foreground (Frost)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(seconds: 3),
                curve: Curves.easeInOut,
                opacity:
                    ref.watch(drawingProvider).canvasEnvironment ==
                        CanvasEnvironment.frozen
                    ? 1.0
                    : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 20,
                    ),
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.lightBlue.withValues(alpha: 0.2),
                      ],
                      radius: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            if (ref.watch(drawingProvider).activeEffect != null)
              Positioned.fill(
                child: ParticleEngine(
                  key: ValueKey(ref.watch(drawingProvider).effectTriggerTime),
                  effect: ref.watch(drawingProvider).activeEffect!,
                  onComplete: () {
                    ref.read(drawingProvider.notifier).clearEasterEgg();
                  },
                ),
              ),

            if (ref.watch(drawingProvider).activeEffect != null)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(ref.watch(drawingProvider).effectTriggerTime),
                    tween: Tween(begin: 0.0, end: 4.0),
                    duration: const Duration(seconds: 4),
                    builder: (context, val, child) {
                      double opacity = 1.0;
                      if (val < 0.5) {
                        opacity = val * 2;
                      } else if (val > 3.0)
                        opacity = (4.0 - val).clamp(0.0, 1.0);

                      return Opacity(
                        opacity: opacity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: kIsWeb
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    ref
                                            .watch(drawingProvider)
                                            .activeEffectMessage ??
                                        "✨ Something magical happened...",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                )
                              : BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 14,
                                    sigmaY: 14,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      ref
                                              .watch(drawingProvider)
                                              .activeEffectMessage ??
                                          "✨ Something magical happened...",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            if (_showToolbox)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: SafeArea(child: Center(child: _buildFloatingDock())),
              ),
            Positioned(top: 100, left: 16, child: _buildScenarioSelector()),
            if (ref.watch(drawingProvider).canvasEnvironment ==
                CanvasEnvironment.normal)
              const Positioned(top: 150, left: 16, child: PhysicsHUD()),
            if (_showExamMode)
              const Positioned(
                top: 100,
                right: 16,
                child: PhysicsExamOverlay(),
              ),
            if (ref.watch(drawingProvider).canvasEnvironment ==
                    CanvasEnvironment.electronics ||
                ref.watch(drawingProvider).canvasEnvironment ==
                    CanvasEnvironment.chemistry) ...[
              ComponentDrawer(
                isOpen: _isComponentDrawerOpen,
                onToggle: () => setState(
                  () => _isComponentDrawerOpen = !_isComponentDrawerOpen,
                ),
              ),
              PropertiesInspector(
                selectedComponentData: _selectedComponentData,
                onUpdateProperty: (key, value) {
                  // Mock update logic
                  setState(() {
                    _selectedComponentData?[key] = value;
                  });
                },
                onClose: () => setState(() => _selectedComponentData = null),
              ),
              Positioned(
                right: 16,
                top: 240,
                child: FloatingActionButton.small(
                  heroTag: 'drawer_toggle',
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  child: Icon(
                    _isComponentDrawerOpen ? Icons.close : Icons.category,
                  ),
                  onPressed: () => setState(
                    () => _isComponentDrawerOpen = !_isComponentDrawerOpen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioSelector() {
    final env = ref.watch(drawingProvider).canvasEnvironment;

    Widget glassChip({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: kIsWeb
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: child,
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
      );
    }

    return Row(
      children: [
        if (env == CanvasEnvironment.normal) ...[
          glassChip(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: PhysicsEngine().currentScenario.name,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primary,
                ),
                isDense: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                items: const [
                  DropdownMenuItem(value: 'Earth', child: Text('🌍 Earth')),
                  DropdownMenuItem(value: 'Moon', child: Text('🌕 Moon')),
                  DropdownMenuItem(value: 'Mars', child: Text('🔴 Mars')),
                  DropdownMenuItem(
                    value: 'Deep Space',
                    child: Text('🌌 Deep Space'),
                  ),
                ],
                          onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    if (val == 'Earth') {
                      PhysicsEngine().setScenario(PhysicsScenario.earth);
                    }
                    if (val == 'Moon') {
                      PhysicsEngine().setScenario(PhysicsScenario.moon);
                    }
                    if (val == 'Mars') {
                      PhysicsEngine().setScenario(PhysicsScenario.mars);
                    }
                    if (val == 'Deep Space') {
                      PhysicsEngine().setScenario(PhysicsScenario.deepSpace);
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        glassChip(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CanvasEnvironment>(
              value: ref.watch(drawingProvider).canvasEnvironment,
              icon: const Icon(Icons.architecture, color: AppColors.primary),
              isDense: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              items: const [
                DropdownMenuItem(
                  value: CanvasEnvironment.normal,
                  child: Text('Standard'),
                ),
                DropdownMenuItem(
                  value: CanvasEnvironment.electronics,
                  child: Text('Electronics'),
                ),
                DropdownMenuItem(
                  value: CanvasEnvironment.chemistry,
                  child: Text('Chemistry'),
                ),
                DropdownMenuItem(
                  value: CanvasEnvironment.frozen,
                  child: Text('Frozen'),
                ),
                DropdownMenuItem(
                  value: CanvasEnvironment.warm,
                  child: Text('Warm'),
                ),
              ],
                          onChanged: (val) {
                if (val != null) {
                  ref.read(drawingProvider.notifier).setCanvasEnvironment(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => setState(() => _showExamMode = !_showExamMode),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: kIsWeb
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _showExamMode
                          ? Colors.purple.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showExamMode
                            ? Colors.purple.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.school,
                          color: _showExamMode ? Colors.white : Colors.purple,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Exam Mode',
                          style: TextStyle(
                            color: _showExamMode ? Colors.white : Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _showExamMode
                            ? Colors.purple.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showExamMode
                              ? Colors.purple.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school,
                            color: _showExamMode ? Colors.white : Colors.purple,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Exam Mode',
                            style: TextStyle(
                              color: _showExamMode
                                  ? Colors.white
                                  : Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── TOOLBOX ─────────────────────────────────────────────────────────────

  Widget _buildFloatingDock() {
    final drawingState = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);
    final currentTool = drawingState.currentTool;
    final currentColor = drawingState.currentColor;

    // Define tool groups
    final navTools = [
      _ToolDef(ToolType.pan, Icons.pan_tool_rounded, 'Pan / Move'),
      _ToolDef(ToolType.select, Icons.highlight_alt_rounded, 'Select'),
    ];
    final drawTools = [
      _ToolDef(ToolType.pen, Icons.edit_rounded, 'Pen'),
      _ToolDef(ToolType.brush, Icons.brush_rounded, 'Brush'),
      _ToolDef(ToolType.highlighter, Icons.format_paint_rounded, 'Highlighter'),
      _ToolDef(ToolType.fill, Icons.format_color_fill, 'Fill'),
      _ToolDef(ToolType.eraser, Icons.auto_fix_high_rounded, 'Eraser'),
    ];
    final specialTools = [
      _ToolDef(ToolType.text, Icons.text_fields_rounded, 'Text'),
      _ToolDef(ToolType.wire, Icons.cable_rounded, 'Wire'),
      _ToolDef(ToolType.portal, Icons.blur_circular_rounded, 'Portal'),
    ];

    // Which single drawing tool is showing in the dock (collapsed)
    final isDrawing = drawTools.any((t) => t.type == currentTool);
    final activeDraw = isDrawing
        ? drawTools.firstWhere(
            (t) => t.type == currentTool,
            orElse: () => drawTools.first,
          )
        : drawTools.first;

    Widget divider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.grey.shade300,
            Colors.transparent,
          ],
        ),
      ),
    );

    Widget toolBtn(_ToolDef def) {
      final sel = currentTool == def.type;
      return Tooltip(
        message: def.label,
        preferBelow: false,
        child: GestureDetector(
          onTap: () {
            if (def.type == ToolType.pen ||
                def.type == ToolType.brush ||
                def.type == ToolType.highlighter ||
                def.type == ToolType.fill ||
                def.type == ToolType.eraser) {
              // If already selected, show settings
              if (sel) {
                _showToolSettingsDialog();
              } else {
                notifier.setTool(def.type);
              }
            } else {
              notifier.setTool(def.type);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF3D5AFE).withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                def.icon,
                size: 20,
                color: sel ? const Color(0xFF3D5AFE) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      );
    }

    // The collapsed draw button that shows active draw tool with a small arrow
    Widget drawToolBtn() {
      final sel = isDrawing;
      return Tooltip(
        message: sel
            ? '${activeDraw.label} (tap again for options)'
            : 'Drawing Tools',
        preferBelow: false,
        child: GestureDetector(
          onTap: () {
            if (!isDrawing) {
              notifier.setTool(ToolType.pen);
            } else {
              // Inline sub-menu to avoid local-function scope issues
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return StatefulBuilder(
                    builder: (context, setSheetState) {
                      final sheetContainer = Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: kIsWeb ? 0.96 : 0.82,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Drawing Tool',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF9CA3AF),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _subToolBtn(
                                  ctx,
                                  notifier,
                                  ToolType.pen,
                                  Icons.edit_rounded,
                                  'Pen',
                                ),
                                const SizedBox(width: 10),
                                _subToolBtn(
                                  ctx,
                                  notifier,
                                  ToolType.brush,
                                  Icons.brush_rounded,
                                  'Brush',
                                ),
                                const SizedBox(width: 10),
                                _subToolBtn(
                                  ctx,
                                  notifier,
                                  ToolType.highlighter,
                                  Icons.format_paint_rounded,
                                  'Highlight',
                                ),
                                const SizedBox(width: 10),
                                _subToolBtn(
                                  ctx,
                                  notifier,
                                  ToolType.fill,
                                  Icons.format_color_fill,
                                  'Fill',
                                ),
                                const SizedBox(width: 10),
                                _subToolBtn(
                                  ctx,
                                  notifier,
                                  ToolType.eraser,
                                  Icons.auto_fix_high_rounded,
                                  'Eraser',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Consumer(
                              builder: (context, ref, _) {
                                final ds = ref.watch(drawingProvider);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stroke Size: ${ds.currentSize.toStringAsFixed(1)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: const Color(
                                          0xFF3D5AFE,
                                        ),
                                        inactiveTrackColor: const Color(
                                          0xFFE5E7EB,
                                        ),
                                        thumbColor: const Color(0xFF3D5AFE),
                                        overlayColor: const Color(
                                          0xFF3D5AFE,
                                        ).withValues(alpha: 0.1),
                                        trackHeight: 3,
                                      ),
                                      child: Slider(
                                        value: ds.currentSize.clamp(
                                          1.0,
                                          ds.currentTool == ToolType.eraser
                                              ? 80.0
                                              : 20.0,
                                        ),
                                        min: 1.0,
                                        max: ds.currentTool == ToolType.eraser
                                            ? 80.0
                                            : 20.0,
                                        onChanged: (v) => ref
                                            .read(drawingProvider.notifier)
                                            .setSize(v),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: kIsWeb
                            ? sheetContainer
                            : BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: sheetContainer,
                              ),
                      );
                    },
                  );
                },
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF3D5AFE).withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeDraw.icon,
                  size: 20,
                  color: sel
                      ? const Color(0xFF3D5AFE)
                      : const Color(0xFF6B7280),
                ),
                if (sel) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final dockContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: kIsWeb ? 0.95 : 0.72),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Utility actions
            _iconAction(
              icon: Icons.undo_rounded,
              tip: 'Undo',
              onTap: () => notifier.undo(),
            ),
            _iconAction(
              icon: Icons.redo_rounded,
              tip: 'Redo',
              onTap: () => notifier.redo(),
            ),
            _iconAction(
              icon: Icons.add_photo_alternate_outlined,
              tip: 'Image',
              onTap: _pickImage,
            ),
            _iconAction(
              icon: Icons.content_paste_rounded,
              tip: 'Paste',
              onTap: _pasteSystemClipboard,
            ),
            divider(),
            // Nav tools
            ...navTools.map(toolBtn),
            divider(),
            // Drawing tools (collapsed)
            drawToolBtn(),
            divider(),
            // Special tools
            ...specialTools.map(toolBtn),
            divider(),
            // Color swatch → opens color+size settings
            Tooltip(
              message: 'Color & Size',
              preferBelow: false,
              child: GestureDetector(
                onTap: _showToolSettingsDialog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: currentColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: kIsWeb
          ? dockContainer
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: dockContainer,
            ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tip,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Center(
            child: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          ),
        ),
      ),
    );
  }

  void _showDrawSubMenu() {
    final notifier = ref.read(drawingProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Drawing Tool',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _subToolBtn(
                    ctx,
                    notifier,
                    ToolType.pen,
                    Icons.edit_rounded,
                    'Pen',
                  ),
                  const SizedBox(width: 10),
                  _subToolBtn(
                    ctx,
                    notifier,
                    ToolType.brush,
                    Icons.brush_rounded,
                    'Brush',
                  ),
                  const SizedBox(width: 10),
                  _subToolBtn(
                    ctx,
                    notifier,
                    ToolType.highlighter,
                    Icons.format_paint_rounded,
                    'Highlight',
                  ),
                  const SizedBox(width: 10),
                  _subToolBtn(
                    ctx,
                    notifier,
                    ToolType.fill,
                    Icons.format_color_fill,
                    'Fill',
                  ),
                  const SizedBox(width: 10),
                  _subToolBtn(
                    ctx,
                    notifier,
                    ToolType.eraser,
                    Icons.auto_fix_high_rounded,
                    'Eraser',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Size slider in sub-menu
              Consumer(
                builder: (context, ref, _) {
                  final ds = ref.watch(drawingProvider);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stroke Size: ${ds.currentSize.toStringAsFixed(1)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF3D5AFE),
                          inactiveTrackColor: const Color(0xFFE5E7EB),
                          thumbColor: const Color(0xFF3D5AFE),
                          overlayColor: const Color(
                            0xFF3D5AFE,
                          ).withValues(alpha: 0.1),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: ds.currentSize.clamp(
                            1.0,
                            ds.currentTool == ToolType.eraser ? 80.0 : 20.0,
                          ),
                          min: 1.0,
                          max: ds.currentTool == ToolType.eraser ? 80.0 : 20.0,
                          onChanged: (v) =>
                              ref.read(drawingProvider.notifier).setSize(v),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _subToolBtn(
    BuildContext ctx,
    DrawingNotifier notifier,
    ToolType type,
    IconData icon,
    String label,
  ) {
    final currentTool = ref.watch(drawingProvider).currentTool;
    final sel = currentTool == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          notifier.setTool(type);
          Navigator.pop(ctx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0xFF3D5AFE).withValues(alpha: 0.1)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? const Color(0xFF3D5AFE) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: sel ? const Color(0xFF3D5AFE) : const Color(0xFF6B7280),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel
                      ? const Color(0xFF3D5AFE)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToolSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final drawingState = ref.watch(drawingProvider);
            final notifier = ref.read(drawingProvider.notifier);

            final colors = [
              Colors.black,
              const Color(0xFF1E293B),
              const Color(0xFF3D5AFE),
              const Color(0xFF7C3AED),
              const Color(0xFFEC4899),
              const Color(0xFFEF4444),
              const Color(0xFFF59E0B),
              const Color(0xFF10B981),
              const Color(0xFF06B6D4),
              Colors.white,
            ];

            return Container(
              margin: const EdgeInsets.all(16),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Color Section
                  if (drawingState.currentTool != ToolType.eraser &&
                      drawingState.currentTool != ToolType.wire &&
                      drawingState.currentTool != ToolType.portal) ...[
                    Text(
                      'Color',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colors.map((c) {
                        final isSel =
                            drawingState.currentColor.toARGB32() ==
                            c.toARGB32();
                        return GestureDetector(
                          onTap: () => notifier.setColor(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSel ? 42 : 38,
                            height: isSel ? 42 : 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? const Color(0xFF3D5AFE)
                                    : Colors.grey.shade200,
                                width: isSel ? 2.5 : 1,
                              ),
                              boxShadow: [
                                if (isSel)
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSel
                                ? const Center(
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Size Section
                  if (drawingState.currentTool != ToolType.wire &&
                      drawingState.currentTool != ToolType.portal) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stroke Size',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            drawingState.currentSize.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          size: 6,
                          color: Color(0xFF9CA3AF),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF3D5AFE),
                              inactiveTrackColor: const Color(0xFFE5E7EB),
                              thumbColor: const Color(0xFF3D5AFE),
                              overlayColor: const Color(
                                0xFF3D5AFE,
                              ).withValues(alpha: 0.1),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: drawingState.currentSize.clamp(
                                1.0,
                                drawingState.currentTool == ToolType.eraser
                                    ? 80.0
                                    : 20.0,
                              ),
                              min: 1.0,
                              max: drawingState.currentTool == ToolType.eraser
                                  ? 80.0
                                  : 20.0,
                              onChanged: notifier.setSize,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.fiber_manual_record,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Offset _getViewportCenter() {
    if (_canvasKey.currentState == null) return const Offset(50000, 50000);
    final matrix = _canvasKey.currentState!.transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    final size = MediaQuery.of(context).size;
    return Offset(
      (-translation.x + size.width / 2) / scale,
      (-translation.y + size.height / 2) / scale,
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      _insertImageSmart(bytes);
    }
  }

  void _insertImageSmart(Uint8List bytes) {
    final strokes = ref.read(drawingProvider).strokes;
    Offset targetPos = _getViewportCenter();

    final transform =
        _canvasKey.currentState?.transformationController.value ??
        Matrix4.identity();
    final inverse = Matrix4.copy(transform)..invert();
    final size = MediaQuery.of(context).size;
    final viewportRect = Rect.fromPoints(
      MatrixUtils.transformPoint(inverse, const Offset(0, 0)),
      MatrixUtils.transformPoint(inverse, Offset(size.width, size.height)),
    );

    double maxY = double.negativeInfinity;

    for (var stroke in strokes) {
      if (stroke.bounds.overlaps(viewportRect)) {
        if (stroke.bounds.bottom > maxY) {
          maxY = stroke.bounds.bottom;
        }
      }
    }

    if (maxY != double.negativeInfinity) {
      // Place it safely below the lowest item in the current view
      targetPos = Offset(targetPos.dx, maxY + 50);
    }

    ref.read(drawingProvider.notifier).insertImage(bytes, targetPos);

    // Auto-pan the camera to the newly pasted image
    if (_canvasKey.currentState != null) {
      final matrix = _canvasKey.currentState!.transformationController.value;
      final scale = matrix.getMaxScaleOnAxis();
      final size = MediaQuery.of(context).size;
      final newMatrix = matrix.clone();
      newMatrix.setTranslationRaw(
        (size.width / 2) - (targetPos.dx * scale),
        (size.height / 2) - (targetPos.dy * scale),
        0,
      );
      _canvasKey.currentState!.transformationController.value = newMatrix;
    }
  }

  Future<void> _pasteSystemClipboard() async {
    // 1. Try to paste image first (from Pasteboard)
    final bytes = await Pasteboard.image;
    if (!mounted) return;
    if (bytes != null) {
      _insertImageSmart(bytes);
      return;
    }

    // 2. Try to paste text (from Flutter Clipboard)
    final textData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (textData != null &&
        textData.text != null &&
        textData.text!.isNotEmpty) {
      final transform =
          _canvasKey.currentState?.transformationController.value ??
          Matrix4.identity();
      final inverse = Matrix4.copy(transform)..invert();
      final size = MediaQuery.of(context).size;
      final center = MatrixUtils.transformPoint(
        inverse,
        Offset(size.width / 2, size.height / 2),
      );

      final isDark =
          (ref.read(drawingProvider).canvasBackgroundColor ?? Colors.white)
              .computeLuminance() <
          0.5;
      final stroke = AiStrokeGenerator.generateText(
        textData.text!,
        center.dx,
        center.dy,
        isDark ? Colors.white : Colors.black,
        18.0 * 3.0,
        customMetadata: const {'isAiGenerated': false},
      );
      ref.read(drawingProvider.notifier).addStrokes([stroke]);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nothing to paste (no image or text found in clipboard).',
        ),
      ),
    );
  }

  Future<void> _showUmlDialog() async {
    final controller = TextEditingController(
      text: ''
    );
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Advanced UML'),
              content: SizedBox(
                width: 500,
                child: TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Enter PlantUML syntax...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          final bytes = await PlantUmlService.fetchUmlImage(
                            controller.text,
                          );
                          if (mounted) {
                            setState(() => isLoading = false);
                            if (bytes != null) {
                              navigator.pop();
                              _insertImageSmart(bytes);
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to generate UML'),
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveCurrentCanvas() {
    if (!mounted) return;
    final strokes = ref.read(drawingProvider).strokes;
    final existingPage = ref.read(canvasProvider).first;
    final updatedPage = AppCanvas(
      id: existingPage.id,
      title: existingPage.title,
      dateCreated: existingPage.dateCreated,
      isStarred: existingPage.isStarred,
      strokes: strokes,
    );
    ref.read(canvasProvider.notifier).updateCanvas(updatedPage);
  }

  void _saveAndExit() {
    // Save state needed for background save
    final strokesToSave = List<Stroke>.from(ref.read(drawingProvider).strokes);
    final currentPageIdToSave = _currentCanvasId;

    // Pop the screen first to avoid Navigator locks!
    Navigator.pop(context);

    // Save quietly in the background after the pop is initiated
    Future.microtask(() {
      final canvases = ref.read(canvasProvider);
      final existingPage = canvases.firstWhere(
        (p) => p.id == currentPageIdToSave,
      );

      final updatedPage = AppCanvas(
        id: existingPage.id,
        title: existingPage.title,
        dateCreated: existingPage.dateCreated,
        isStarred: existingPage.isStarred,
        strokes: strokesToSave,
      );
      ref.read(canvasProvider.notifier).updateCanvas(updatedPage);
    });
  }

  void _showCanvasMenu(BuildContext context, dynamic page) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 260),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _buildCustomMenuContent(page),
        ),
      ],
    );
  }

  Widget _buildCustomMenuContent(dynamic page) {
    return StatefulBuilder(
      builder: (context, setMenuState) {
                            final currentAnim = ref.watch(drawingProvider).easterEggMode;
        Widget buildHeader(String title) {
          return Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 8,
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B9EB7),
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        Widget buildSwitchItem(
          IconData icon,
          String title,
          bool value,
          ValueChanged<bool> onChanged, {
          bool hasNewBadge = false,
        }) {
          return InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF5C6B89)),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2E384D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasNewBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1A73E8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: 24,
                    child: Transform.scale(
                      scale: 0.8,
                      child: CupertinoSwitch(
                        value: value,
                        onChanged: onChanged,
                        activeTrackColor: const Color(0xFF3D5AFE),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildActionItem(
          IconData icon,
          String title,
          VoidCallback onTap, {
          bool isDestructive = false,
          bool hasNewBadge = false,
        }) {
          final color = isDestructive
              ? const Color(0xFFD32F2F)
              : const Color(0xFF2E384D);
          final iconColor = isDestructive
              ? const Color(0xFFD32F2F)
              : const Color(0xFF5C6B89);
          return InkWell(
            onTap: () {
              Navigator.pop(context);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasNewBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1A73E8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHeader('VIEW'),
            buildSwitchItem(Icons.grid_view, 'Show toolbox', _showToolbox, (
              val,
            ) {
              setState(() => _showToolbox = val);
              setMenuState(() {});
            }),
            buildActionItem(Icons.auto_awesome, 'Animations', () {
              showDialog(
                context: context,
                builder: (context) {
                  final currentMode = ref.read(drawingProvider).easterEggMode;
                  return AlertDialog(
                    title: const Text('Animation Options'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: EasterEggMode.values.map((mode) {
                        return RadioListTile<EasterEggMode>(
                          title: Text(
                            mode.name.substring(0, 1).toUpperCase() +
                                mode.name.substring(1),
                          ),
                          value: mode,
                          groupValue: currentMode,
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(drawingProvider.notifier)
                                  .setEasterEggMode(val);
                              Navigator.pop(context);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            }, hasNewBadge: true),
            buildActionItem(Icons.center_focus_strong, 'Focus', () {
              final strokes = ref.read(drawingProvider).strokes;
              if (strokes.isNotEmpty) {
                final stroke = strokes.last;
                _focusOnTarget(
                  stroke.bounds.center,
                  intent: CameraIntent.userAssistedFocus,
                  trackingStrokeId: stroke.id,
                );
              }
            }, hasNewBadge: false),
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            buildHeader('CANVAS'),
            buildActionItem(
              Icons.edit,
              'Rename canvas',
              () => _showRenameDialog(page),
            ),
            buildActionItem(
              Icons.military_tech,
              'Achievements',
              () => showDialog(
                context: context,
                builder: (_) => const AchievementsDialog(),
              ),
            ),
            buildActionItem(Icons.cloud_upload, 'Sync to Cloud', () async {
              final messenger = ScaffoldMessenger.of(context);
              await CloudSyncService().syncCanvasToCloud(page);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Canvas synced successfully!')),
                );
              }
            }),
            buildActionItem(Icons.group_add, 'Distribute to Class', () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                final lmsNotifier = ref.read(lmsProvider.notifier);
                final lessonId = await lmsNotifier.distributeCurrentLesson(
                  page.title,
                  "vinci://lesson/${page.id}",
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Lesson distributed! ID: $lessonId'),
                    ),
                  );
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TeacherDashboardScreen(lessonId: lessonId),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to distribute: $e')),
                  );
                }
              }
            }, hasNewBadge: true),
            buildActionItem(Icons.picture_as_pdf, 'Export to PDF', () async {
              final messenger = ScaffoldMessenger.of(context);
              final size = MediaQuery.of(context).size;
              final strokes = ref.read(drawingProvider).strokes;
              final path = await ExportService.exportToPdf(
                strokes,
                size,
                "export_${page.id}",
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Exported PDF to: $path')),
                );
              }
            }),
            buildActionItem(
              Icons.workspace_premium,
              'Upgrade to Premium',
              () async {
                final messenger = ScaffoldMessenger.of(context);
                final success = await MonetizationService().purchasePremium();
                if (success && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Welcome to Vinci Board Premium!'),
                    ),
                  );
                }
              },
            ),
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            buildActionItem(
              Icons.auto_fix_high,
              'Clear page',
              () => ref.read(drawingProvider.notifier).clear(),
              isDestructive: true,
            ),
            buildActionItem(Icons.delete_outline, 'Delete canvas', () {
              Navigator.of(context).pop(); // pop the canvas screen
              Future.delayed(const Duration(milliseconds: 300), () {
                ref.read(canvasProvider.notifier).deleteCanvas(page.id);
              });
            }, isDestructive: true),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showSpiceDialog() {
    final spice = TeslaEngine().generateSpiceNetlist();
    _showCodeDialog('SPICE Export', spice);
  }

  void _showCodeDialog(String title, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            code,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(AppCanvas page) {
    final controller = TextEditingController(text: page.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Note Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                ref
                    .read(canvasProvider.notifier)
                    .renameCanvas(page.id, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEditor() {
    final matrix = _canvasKey.currentState?.transformationController.value ?? Matrix4.identity();
    final canvasPos = _editingPosition!;
    final screenPos = MatrixUtils.transformPoint(matrix, canvasPos);
    
    final double scale = matrix.getMaxScaleOnAxis();
    final double scaledFontSize = (18.0 * scale).clamp(12.0, 72.0);

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 500.0 * scale,
          child: TextField(
            controller: _editingController,
            focusNode: _editingFocusNode,
            maxLines: null,
            autofocus: true,
            showCursor: true,
            cursorColor: ref.watch(drawingProvider).currentColor,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: scaledFontSize,
              color: ref.watch(drawingProvider).currentColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: "Type text... (Shift+Enter to ask AI)",
              hintStyle: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
                fontSize: scaledFontSize,
              ),
            ),
            onSubmitted: (_) => _stopInlineEditing(),
          ),
        ),
      ),
    );
  }
}

class GoldenRatioOverlay extends StatelessWidget {
  const GoldenRatioOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: GoldenRatioPainter(), size: Size.infinite),
    );
  }
}

class GoldenRatioPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw a simple golden ratio grid or spiral
    // For simplicity, we draw the phi grid (1 : 1.618 : 1)
    final phi = 1.61803398875;
    final total = 1 + phi + 1;
    final w1 = size.width / total;
    final w2 = w1 * phi;
    final h1 = size.height / total;
    final h2 = h1 * phi;

    canvas.drawLine(Offset(w1, 0), Offset(w1, size.height), paint);
    canvas.drawLine(Offset(w1 + w2, 0), Offset(w1 + w2, size.height), paint);

    canvas.drawLine(Offset(0, h1), Offset(size.width, h1), paint);
    canvas.drawLine(Offset(0, h1 + h2), Offset(size.width, h1 + h2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple data class used by the new toolbox
class _ToolDef {
  final ToolType type;
  final IconData icon;
  final String label;
  const _ToolDef(this.type, this.icon, this.label);
}
