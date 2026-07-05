import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import '../models/easter_egg_mode.dart';
import '../models/canvas_environment.dart';
import '../engine/canvas_widget.dart';
import '../engine/spatial_layout_engine.dart';
import '../engine/cognitive/cognitive_runtime.dart';
import '../engine/particle_engine.dart';
import '../providers/drawing_provider.dart';
import '../providers/notebook_provider.dart';
import '../providers/settings_provider.dart';
import 'package:flutter/services.dart';
import '../widgets/achievements_dialog.dart';
import '../models/tool_type.dart';
import '../models/page.dart';
import '../models/stroke.dart';
import '../services/plantuml_service.dart';
import 'ai_chat_panel.dart';
import '../core/event_bus.dart';
import '../widgets/quiz_overlay.dart';
import '../engine/semantic_camera.dart';
import '../utils/ai_stroke_generator.dart';
import '../core/theme/da_vinci_theme.dart';
import '../widgets/gold_glow_container.dart';
import '../core/widgets/glass_container.dart';
class CanvasScreen extends ConsumerStatefulWidget {
  final String notebookId;
  final String pageId;

  const CanvasScreen({super.key, required this.notebookId, required this.pageId});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with TickerProviderStateMixin {
  late String _currentPageId = widget.pageId;
  bool _isChatOpen = false;
  bool _showToolbox = true;
  final GlobalKey<CanvasWidgetState> _canvasKey = GlobalKey<CanvasWidgetState>();
  final FocusNode _canvasFocusNode = FocusNode();

  AnimationController? _cameraController;
  Animation<Matrix4>? _cameraAnimation;

  void _focusOnTarget(Offset targetCenter, {CameraIntent intent = CameraIntent.hardFocus}) {
    if (_canvasKey.currentState == null) return;
    
    final size = MediaQuery.of(context).size;
    final controller = _canvasKey.currentState!.transformationController;
    final currentMatrix = controller.value;
    
    final targetScale = currentMatrix.getMaxScaleOnAxis(); 
    
    final chatPanelWidth = _isChatOpen ? 400.0 : 0.0;
    final availableWidth = size.width - chatPanelWidth; 
    
    final targetX = (availableWidth / 2) - (targetCenter.dx * targetScale);
    final targetY = (size.height / 2) - (targetCenter.dy * targetScale);

    final targetMatrix = Matrix4.identity()
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
    
    _cameraAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _cameraController!,
      curve: intent == CameraIntent.softGuide ? Curves.easeOutCubic : Curves.easeInOut,
    ));
    
    _cameraAnimation!.addListener(() {
      controller.value = _cameraAnimation!.value;
    });
    
    _cameraController!.forward();
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPageStrokes();
      // Listen for text-insert requests from the canvas (text tool taps)
      ref.read(drawingProvider.notifier).textInsertRequest.addListener(_onTextInsertRequest);
    });
    EventBus().subscribe(EventType.aiActionDispatched, _handleQuizEvent);
    EventBus().subscribe(EventType.aiTaskCompleted, _handleAiTaskCompleted);
    CognitiveRuntime().initialize();
  }

  @override
  void dispose() {
    ref.read(drawingProvider.notifier).textInsertRequest.removeListener(_onTextInsertRequest);
    CognitiveRuntime().shutdown();
    _cameraController?.dispose();
    _canvasFocusNode.dispose();
    super.dispose();
  }

  void _onTextInsertRequest() {
    final pos = ref.read(drawingProvider.notifier).textInsertRequest.value;
    if (pos == null) return;
    // Reset so the listener doesn't fire again immediately
    ref.read(drawingProvider.notifier).textInsertRequest.value = null;
    _showTextInputDialog(pos);
  }

  Future<void> _showTextInputDialog(Offset canvasPosition) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Type your text here...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Place'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      ref.read(drawingProvider.notifier).placeText(result.trim(), canvasPosition);
    }
    controller.dispose();
  }

  void _handleAiTaskCompleted(CanvasEvent event) {
    if (_canvasKey.currentState == null) return;
    
    final intent = event.payload['intent'] as CameraIntent?;
    if (intent == CameraIntent.noAction) return;
    
    final bounds = ref.read(drawingProvider).lastAddedBounds;
    if (bounds == null) return;
    
    Future.delayed(const Duration(milliseconds: 300), () {
       if (mounted) _focusOnTarget(bounds.center, intent: intent ?? CameraIntent.hardFocus);
    });
  }

  void _handleQuizEvent(CanvasEvent event) {
    if (event.payload['action'] == 'trigger_quiz') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => QuizOverlay(
          quizData: event.payload,
          onComplete: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  void _loadPageStrokes() {
    try {
      final notebooks = ref.read(notebookProvider);
      final notebook = notebooks.firstWhere((n) => n.id == widget.notebookId);
      final page = notebook.pages.firstWhere((p) => p.id == _currentPageId);
      ref.read(drawingProvider.notifier).loadStrokes(page.strokes);
    } catch (e) {
      debugPrint('Failed to load strokes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen(drawingProvider) removed to prevent 60fps QuadTree churn during dragging.
    // Spatial rebuild is now manually triggered in DrawingProvider (endStroke, loadStrokes, etc).

    final notebooks = ref.watch(notebookProvider);
    final notebook = notebooks.firstWhere((n) => n.id == widget.notebookId);
    final pageIndex = notebook.pages.indexWhere((p) => p.id == _currentPageId);
    if (pageIndex == -1) {
      return const Scaffold(body: Center(child: Text('Page not found')));
    }
    final page = notebook.pages[pageIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => _saveAndExit(),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.back, color: Color(0xFF3D5AFE), size: 18),
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
          // Page navigation pill
          Container(
            margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      CupertinoIcons.chevron_left,
                      size: 14,
                      color: pageIndex > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                    onPressed: pageIndex > 0
                        ? () {
                            _saveCurrentPage();
                            setState(() { _currentPageId = notebook.pages[pageIndex - 1].id; });
                            _loadPageStrokes();
                          }
                        : null,
                  ),
                ),
                Text(
                  'Page ${pageIndex + 1}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
                SizedBox(
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: pageIndex < notebook.pages.length - 1 ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                    onPressed: pageIndex < notebook.pages.length - 1
                        ? () {
                            _saveCurrentPage();
                            setState(() { _currentPageId = notebook.pages[pageIndex + 1].id; });
                            _loadPageStrokes();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
          // Add page button
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
            child: GestureDetector(
              onTap: () async {
                _saveCurrentPage();
                await ref.read(notebookProvider.notifier).addPage(widget.notebookId);
                if (!mounted) return;
                final updatedNotebook = ref.read(notebookProvider).firstWhere((n) => n.id == widget.notebookId);
                final newPage = updatedNotebook.pages.last;
                setState(() { _currentPageId = newPage.id; });
                _loadPageStrokes();
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 4),

          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary, size: 20),
              onPressed: () => _showCanvasMenu(ctx, notebook, page),
            ),
          ),
        ],
      ),
      body: Focus(
        focusNode: _canvasFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (!_canvasFocusNode.hasPrimaryFocus) return KeyEventResult.ignored;
          if (!ref.read(settingsProvider).enableKeyboardShortcuts) return KeyEventResult.ignored;
          if (event is KeyDownEvent) {
            final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                           HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight) ||
                           HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaLeft) ||
                           HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaRight);
            final isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                            HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
                           
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
                final pasted = ref.read(drawingProvider.notifier).pasteFromClipboard();
                if (!pasted) {
                  _pasteSystemClipboard();
                }
                return KeyEventResult.handled;
              }
            } else {
              if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
                if (FocusManager.instance.primaryFocus != node) {
                  return KeyEventResult.ignored;
                }
                ref.read(drawingProvider.notifier).deleteSelection();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                // To deselect, we can call a method or just trigger empty selectStrokesInRect
                ref.read(drawingProvider.notifier).selectStrokesInRect(Rect.zero);
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
              color: ref.watch(drawingProvider).canvasBackgroundColor ?? AppColors.background,
            ),
            // Environment Background
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            color:
                ref.watch(drawingProvider).canvasEnvironment ==
                    CanvasEnvironment.warm
                ? Colors.orange.withOpacity(0.15)
                : (ref.watch(drawingProvider).canvasEnvironment ==
                          CanvasEnvironment.frozen
                      ? Colors.blue.withOpacity(0.05)
                      : Colors.transparent),
          ),
          Listener(
            onPointerDown: (_) {
              if (!_canvasFocusNode.hasPrimaryFocus) {
                _canvasFocusNode.requestFocus();
              }
            },
            child: CanvasWidget(key: _canvasKey),
          ),
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
                    color: Colors.white.withOpacity(0.6),
                    width: 20,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.lightBlue.withOpacity(0.2),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "✨ Something magical happened...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),


          Positioned(
            right: 16,
            bottom: 110, // Avoid overlapping the dock
            child: Offstage(
              offstage: !_isChatOpen,
              child: AiChatPanel(
                onDrawStart: () {
                  setState(() => _isChatOpen = false);
                },
                onDrawEnd: (newMaxY) {
                  setState(() => _isChatOpen = true);
                },
                onClose: _toggleChat,
                getTransform: () => _canvasKey.currentState?.transformationController.value,
              ),
            ),
          ),
          if (!_isChatOpen)
            Positioned(
              right: 16,
              bottom: 32,
              child: FloatingActionButton(
                onPressed: _toggleChat,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                shape: const CircleBorder(),
                child: const Icon(Icons.chat_bubble_outline, size: 28),
              ),
            ),
          if (_showToolbox)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(child: Center(child: _buildFloatingDock())),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildFloatingDock() {
    final divider = Container(
      width: 1, height: 24,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dockIcon(icon: const Icon(CupertinoIcons.photo, size: 20), tooltip: 'Insert Image', onTap: _pickImage),
            _dockIcon(icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 20), tooltip: 'Paste', onTap: _pasteSystemClipboard),
            _dockIcon(icon: const Icon(CupertinoIcons.share, size: 20), tooltip: 'UML', onTap: _showUmlDialog),
            divider,
            _dockIcon(icon: const Icon(CupertinoIcons.arrow_uturn_left, size: 20), tooltip: 'Undo', onTap: () => ref.read(drawingProvider.notifier).undo()),
            _dockIcon(icon: const Icon(CupertinoIcons.arrow_uturn_right, size: 20), tooltip: 'Redo', onTap: () => ref.read(drawingProvider.notifier).redo()),
            divider,
            _buildToolButton(ToolType.pan, CupertinoIcons.hand_raised),
            _buildToolButton(ToolType.select, CupertinoIcons.selection_pin_in_out),
            _buildDrawingToolButton(),
            _buildToolButton(ToolType.highlighter, CupertinoIcons.paintbrush),
            _buildToolButton(ToolType.eraser, _buildEraserIcon),
            _buildToolButton(ToolType.text, CupertinoIcons.textformat),
            _buildToolButton(ToolType.wire, CupertinoIcons.link),
            _buildToolButton(ToolType.portal, CupertinoIcons.circle),
            divider,
            GestureDetector(
              onTap: () => _showToolSettingsDialog(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ref.watch(drawingProvider).currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: ref.watch(drawingProvider).currentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockIcon({required Widget icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: const Color(0xFF3D5AFE).withValues(alpha: 0.65), size: 20),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingToolButton() {
    final currentTool = ref.watch(drawingProvider).currentTool;
    final isDrawingTool =
        currentTool == ToolType.pen ||
        currentTool == ToolType.brush ||
        currentTool == ToolType.fill;

    IconData icon;
    if (currentTool == ToolType.brush) {
      icon = Icons.brush;
    } else if (currentTool == ToolType.fill)
      icon = CupertinoIcons.drop_fill;
    else
      icon = Icons.edit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDrawingTool ? const Color(0xFFEEF2FF) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: isDrawingTool ? AppColors.primary : const Color(0xFF3D5AFE).withValues(alpha: 0.65),
            size: 20,
          ),
          onPressed: () {
            if (isDrawingTool) {
              _showToolSettingsDialog();
            } else {
              ref.read(drawingProvider.notifier).setTool(ToolType.pen);
            }
          },
        ),
      ),
    );
  }

  Widget _buildToolButton(ToolType type, dynamic iconOrBuilder) {
    final currentTool = ref.watch(drawingProvider).currentTool;
    final isSelected = currentTool == type;

    Widget iconWidget;
    if (iconOrBuilder is IconData) {
      iconWidget = Icon(
        iconOrBuilder,
        color: isSelected ? AppColors.primary : const Color(0xFF3D5AFE).withValues(alpha: 0.65),
        size: 20,
      );
    } else if (iconOrBuilder is Widget Function(bool)) {
      iconWidget = iconOrBuilder(isSelected);
    } else {
      iconWidget = const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: iconWidget,
          onPressed: () {
            if (isSelected && type != ToolType.text) {
              _showToolSettingsDialog();
            } else {
              ref.read(drawingProvider.notifier).setTool(type);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEraserIcon(bool isSelected) {
    return Transform.rotate(
      angle: -0.5,
      child: Container(
        width: 22,
        height: 12,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                color: isSelected ? AppColors.accent : AppColors.primary,
              ),
            ),
            Expanded(child: Container()),
          ],
        ),
      ),
    );
  }

  void _showToolSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final drawingState = ref.watch(drawingProvider);
            final notifier = ref.read(drawingProvider.notifier);

            final colors = [
              Colors.black,
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.accent,
              AppColors.error,
              Colors.blueGrey,
              Colors.brown,
            ];

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (drawingState.currentTool == ToolType.pen ||
                      drawingState.currentTool == ToolType.brush ||
                      drawingState.currentTool == ToolType.fill) ...[
                    const Text(
                      'Drawing Tool',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<ToolType>(
                        groupValue: drawingState.currentTool,
                        children: const {
                          ToolType.pen: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Pen'),
                          ),
                          ToolType.brush: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Brush'),
                          ),
                          ToolType.fill: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Fill'),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val != null) {
                            notifier.setTool(val);
                            // Auto-close dialog after selection for a snappier feel
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (drawingState.currentTool != ToolType.wire && drawingState.currentTool != ToolType.portal) ...[
                    const Text(
                      'Quill Nib Size',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 10 + (drawingState.currentSize / 2), color: AppColors.primaryDark),
                        Expanded(
                          child: Slider(
                            value: drawingState.currentSize.clamp(
                              1.0,
                              drawingState.currentTool == ToolType.eraser ? 80.0 : 20.0,
                            ),
                            min: 1.0,
                            max: drawingState.currentTool == ToolType.eraser
                                ? 80.0
                                : 20.0,
                            activeColor: AppColors.accent,
                            inactiveColor: AppColors.primary.withOpacity(0.3),
                            onChanged: (val) {
                              notifier.setSize(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (drawingState.currentTool != ToolType.eraser && drawingState.currentTool != ToolType.wire && drawingState.currentTool != ToolType.portal) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Color',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: colors.map((c) {
                        final isSelectedColor =
                            drawingState.currentColor.value == c.value;
                        return GestureDetector(
                          onTap: () {
                            notifier.setColor(c);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelectedColor ? AppColors.accent : Colors.black26, 
                                width: isSelectedColor ? 3 : 1
                              ),
                              boxShadow: [
                                if (isSelectedColor)
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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

    final transform = _canvasKey.currentState?.transformationController.value ?? Matrix4.identity();
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
    if (bytes != null) {
      _insertImageSmart(bytes);
      return;
    }
    
    // 2. Try to paste text (from Flutter Clipboard)
    final textData = await Clipboard.getData(Clipboard.kTextPlain);
    if (textData != null && textData.text != null && textData.text!.isNotEmpty) {
      final transform = _canvasKey.currentState?.transformationController.value ?? Matrix4.identity();
      final inverse = Matrix4.copy(transform)..invert();
      final size = MediaQuery.of(context).size;
      final center = MatrixUtils.transformPoint(inverse, Offset(size.width / 2, size.height / 2));
      
      final isDark = (ref.read(drawingProvider).canvasBackgroundColor ?? Colors.white).computeLuminance() < 0.5;
      final stroke = AiStrokeGenerator.generateText(textData.text!, center.dx, center.dy, isDark ? Colors.white : Colors.black, 18.0 * 3.0);
      ref.read(drawingProvider.notifier).addStrokes([stroke]);
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to paste (no image or text found in clipboard).')),
    );
  }

  Future<void> _showUmlDialog() async {
    final controller = TextEditingController(
      text:
          '// Need PlantUML code?\n// 1. Ask the AI Assistant: "Generate a UML mindmap for..."\n// 2. Ask ChatGPT or Claude to write it for you\n// 3. Or write your own syntax here!',
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
                          final bytes = await PlantUmlService.fetchUmlImage(
                            controller.text,
                          );
                          if (mounted) {
                            setState(() => isLoading = false);
                            if (bytes != null) {
                              Navigator.pop(context);
                              _insertImageSmart(bytes);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
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

  void _saveCurrentPage() {
    if (!mounted) return;
    final strokes = ref.read(drawingProvider).strokes;
    final notebooks = ref.read(notebookProvider);
    final notebook = notebooks.firstWhere((n) => n.id == widget.notebookId);
    final existingPage = notebook.pages.firstWhere(
      (p) => p.id == _currentPageId,
    );

    final updatedPage = NotePage(
      id: existingPage.id,
      title: existingPage.title,
      dateCreated: existingPage.dateCreated,
      isStarred: existingPage.isStarred,
      strokes: strokes,
    );
    ref
        .read(notebookProvider.notifier)
        .updatePage(widget.notebookId, updatedPage);
  }

  void _saveAndExit() {
    // Save state needed for background save
    final strokesToSave = List<Stroke>.from(ref.read(drawingProvider).strokes);
    final currentPageIdToSave = _currentPageId;
    final notebookIdToSave = widget.notebookId;

    // Pop the screen first to avoid Navigator locks!
    Navigator.pop(context);

    // Save quietly in the background after the pop is initiated
    Future.microtask(() {
      final notebooks = ref.read(notebookProvider);
      final notebook = notebooks.firstWhere((n) => n.id == notebookIdToSave);
      final existingPage = notebook.pages.firstWhere(
        (p) => p.id == currentPageIdToSave,
      );

      final updatedPage = NotePage(
        id: existingPage.id,
        title: existingPage.title,
        dateCreated: existingPage.dateCreated,
        isStarred: existingPage.isStarred,
        strokes: strokesToSave,
      );
      ref
          .read(notebookProvider.notifier)
          .updatePage(notebookIdToSave, updatedPage);
    });
  }

  void _showCanvasMenu(BuildContext context, dynamic notebook, dynamic page) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
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
          child: _buildCustomMenuContent(notebook, page),
        ),
      ],
    );
  }

  Widget _buildCustomMenuContent(dynamic notebook, dynamic page) {
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentAnim = ref.watch(drawingProvider).easterEggMode;
        Widget buildHeader(String title) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B9EB7), letterSpacing: 0.5),
            ),
          );
        }
        Widget buildSwitchItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged, {bool hasNewBadge = false}) {
          return InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF5C6B89)),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontSize: 15, color: Color(0xFF2E384D), fontWeight: FontWeight.w500)),
                  if (hasNewBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
                      child: const Text('New', style: TextStyle(fontSize: 10, color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: 24,
                    child: Transform.scale(
                      scale: 0.8,
                      child: CupertinoSwitch(value: value, onChanged: onChanged, activeColor: const Color(0xFF3D5AFE)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        Widget buildActionItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
          final color = isDestructive ? const Color(0xFFD32F2F) : const Color(0xFF2E384D);
          final iconColor = isDestructive ? const Color(0xFFD32F2F) : const Color(0xFF5C6B89);
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
                  Text(title, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
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
            buildSwitchItem(
              Icons.grid_view, 'Show toolbox', _showToolbox,
              (val) {
                setState(() => _showToolbox = val);
                setMenuState(() {});
              },
            ),
            buildSwitchItem(
              Icons.auto_awesome, 'Animations', currentAnim == EasterEggMode.discovery,
              (val) {
                ref.read(drawingProvider.notifier).setEasterEggMode(
                  val ? EasterEggMode.discovery : EasterEggMode.normal
                );
              }, hasNewBadge: true,
            ),
            buildSwitchItem(
              Icons.center_focus_strong, 'Focus AI output', false,
              (val) {
                final bounds = ref.read(drawingProvider).lastAddedBounds;
                if (bounds != null && _canvasKey.currentState != null) {
                  final size = MediaQuery.of(context).size;
                  final padding = 200.0;
                  final scaleX = size.width / (bounds.width + padding);
                  final scaleY = size.height / (bounds.height + padding);
                  final targetScale = math.min(scaleX, scaleY).clamp(0.2, 3.0);
                  final targetX = (size.width / 2) - (bounds.center.dx * targetScale);
                  final targetY = (size.height / 2) - (bounds.center.dy * targetScale);
                  _canvasKey.currentState!.transformationController.value = Matrix4.identity()..translate(targetX, targetY)..scale(targetScale);
                }
                Navigator.pop(context);
              },
            ),
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            buildHeader('CANVAS'),
            buildActionItem(Icons.edit, 'Rename canvas', () => _showRenameDialog(notebook.id, page)),
            buildActionItem(Icons.military_tech, 'Achievements', () => showDialog(context: context, builder: (_) => const AchievementsDialog())),
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            buildActionItem(Icons.auto_fix_high, 'Clear page', () => ref.read(drawingProvider.notifier).clear(), isDestructive: true),
            buildActionItem(Icons.delete_outline, 'Delete canvas', () {
              Navigator.of(context).pop(); // pop the menu
              Navigator.of(context).pop(); // pop the canvas screen
              Future.delayed(const Duration(milliseconds: 300), () {
                ref.read(notebookProvider.notifier).deletePage(notebook.id, page.id);
              });
            }, isDestructive: true),
            const SizedBox(height: 8),
          ],
        );
      }
    );
  }

  void _showRenameDialog(String notebookId, NotePage page) {
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
                    .read(notebookProvider.notifier)
                    .renamePage(notebookId, page.id, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

class GoldenRatioOverlay extends StatelessWidget {
  const GoldenRatioOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: GoldenRatioPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class GoldenRatioPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withOpacity(0.3)
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

