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
  String _insertionPosition = 'Bottom';
  final GlobalKey<CanvasWidgetState> _canvasKey = GlobalKey<CanvasWidgetState>();

  AnimationController? _cameraController;
  Animation<Matrix4>? _cameraAnimation;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _focusOnTarget(Offset targetCenter) {
    if (_canvasKey.currentState == null) return;
    
    final size = MediaQuery.of(context).size;
    final controller = _canvasKey.currentState!.transformationController;
    final currentMatrix = controller.value;
    
    final targetScale = currentMatrix.getMaxScaleOnAxis(); 
    
    final availableWidth = size.width; 
    final targetX = (availableWidth / 2) - (targetCenter.dx * targetScale);
    final targetY = (size.height / 2) - (targetCenter.dy * targetScale);

    final targetMatrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(targetScale);
      
    _cameraController?.dispose();
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _cameraAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _cameraController!,
      curve: Curves.easeInOut,
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
    });
    EventBus().subscribe(EventType.aiActionDispatched, _handleQuizEvent);
    EventBus().subscribe(EventType.aiTaskCompleted, _handleAiTaskCompleted);
  }

  void _handleAiTaskCompleted(CanvasEvent event) {
    if (_canvasKey.currentState == null) return;
    final intent = event.payload['intent'] as CameraIntent?;
    if (intent == CameraIntent.noAction) return;
    
    // We get the target from drawingNotifier's lastAddedBounds
    final bounds = ref.read(drawingProvider).lastAddedBounds;
    if (bounds == null) return;
    
    // Small delay to let rendering finish
    Future.delayed(const Duration(milliseconds: 300), () {
       if (mounted) _focusOnTarget(bounds.center);
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
    final notebooks = ref.watch(notebookProvider);
    final notebook = notebooks.firstWhere((n) => n.id == widget.notebookId);
    final pageIndex = notebook.pages.indexWhere((p) => p.id == _currentPageId);
    if (pageIndex == -1) {
      return const Scaffold(body: Center(child: Text('Page not found')));
    }
    final page = notebook.pages[pageIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F9), // Very pale cyan background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8), // Glassmorphic look
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => _saveAndExit(),
        ),
        title: Text(
          page.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left),
            onPressed: pageIndex > 0
                ? () {
                    _saveCurrentPage();
                    setState(() {
                      _currentPageId = notebook.pages[pageIndex - 1].id;
                    });
                    _loadPageStrokes();
                  }
                : null,
          ),
          Center(child: Text('${pageIndex + 1}')),
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_right),
            onPressed: pageIndex < notebook.pages.length - 1
                ? () {
                    _saveCurrentPage();
                    setState(() {
                      _currentPageId = notebook.pages[pageIndex + 1].id;
                    });
                    _loadPageStrokes();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.add, size: 24, color: Colors.blueAccent),
            tooltip: 'New Page',
            onPressed: () async {
              _saveCurrentPage();
              await ref.read(notebookProvider.notifier).addPage(widget.notebookId);
              if (!mounted) return;
              final updatedNotebook = ref.read(notebookProvider).firstWhere((n) => n.id == widget.notebookId);
              final newPage = updatedNotebook.pages.last;
              setState(() {
                _currentPageId = newPage.id;
              });
              _loadPageStrokes();
            },
          ),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            color: Colors.white,
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'toggle_toolbox') {
                setState(() {
                  _showToolbox = !_showToolbox;
                });
              } else if (value == 'achievements') {
                showDialog(
                  context: context,
                  builder: (_) => const AchievementsDialog(),
                );
              } else if (value == 'change_layout') {
                _showLayoutDialog();
              } else if (value == 'change_animation') {
                _showAnimationDialog();
              } else if (value == 'rename') {
                _showRenameDialog(notebook.id, page);
              } else if (value == 'delete') {
                Navigator.pop(context); // Pop first
                Future.microtask(() {
                  ref
                      .read(notebookProvider.notifier)
                      .deletePage(notebook.id, page.id);
                });
              } else if (value == 'clear') {
                ref.read(drawingProvider.notifier).clear();
              } else if (value == 'focus') {
                final bounds = ref.read(drawingProvider).lastAddedBounds;
                if (bounds != null && _canvasKey.currentState != null) {
                  final size = MediaQuery.of(context).size;

                  // Calculate the required scale to fit the bounds with padding
                  final padding = 200.0;
                  final scaleX = size.width / (bounds.width + padding);
                  final scaleY = size.height / (bounds.height + padding);
                  // Limit the zoom so it doesn't get too close or too far
                  final targetScale = math.min(scaleX, scaleY).clamp(0.2, 3.0);

                  // Calculate target translation to center the bounds
                  final targetX =
                      (size.width / 2) - (bounds.center.dx * targetScale);
                  final targetY =
                      (size.height / 2) - (bounds.center.dy * targetScale);

                  final newMatrix = Matrix4.identity()
                    ..translate(targetX, targetY)
                    ..scale(targetScale);

                  _canvasKey.currentState!.transformationController.value =
                      newMatrix;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No AI response to focus on!'),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'toggle_toolbox',
                checked: _showToolbox,
                child: const Text('Show Toolbox'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'change_layout',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(CupertinoIcons.arrow_up_down_square, size: 20, color: Colors.black54),
                        SizedBox(width: 12),
                        Text('Insert Layout', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(
                      _insertionPosition,
                      style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'change_animation',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(CupertinoIcons.wand_stars, size: 20, color: Colors.purple),
                        SizedBox(width: 12),
                        Text('Animations', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(
                      ref.watch(drawingProvider).easterEggMode.name[0].toUpperCase() + ref.watch(drawingProvider).easterEggMode.name.substring(1),
                      style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'achievements',
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.rosette,
                      size: 20,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Achievements',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'focus',
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.viewfinder,
                      size: 20,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Focus AI Output',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.pencil,
                      size: 20,
                      color: Colors.black54,
                    ),
                    SizedBox(width: 12),
                    Text('Rename Note'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(CupertinoIcons.clear, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Clear Page'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.trash,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Delete Note',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
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
              color: ref.watch(drawingProvider).canvasBackgroundColor ?? Colors.white,
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

          CanvasWidget(key: _canvasKey),

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
                onCameraFocusRequired: (target) {
                  setState(() => _isChatOpen = false);
                  _focusOnTarget(target);
                },
                onClose: _toggleChat,
                getTransform: () =>
                    _canvasKey.currentState?.transformationController.value,
                insertionPosition: _insertionPosition,
              ),
            ),
          ),
          if (!_isChatOpen)
            Positioned(
              right: 16,
              bottom: 32,
              child: FloatingActionButton(
                onPressed: _toggleChat,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                child: const Icon(CupertinoIcons.chat_bubble_text, size: 28),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.black87),
                  tooltip: 'Insert Image',
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.paste, color: Colors.black87),
                  tooltip: 'Paste Image',
                  onPressed: _pasteSystemClipboard,
                ),
                IconButton(
                  icon: const Icon(Icons.account_tree, color: Colors.black87),
                  tooltip: 'Create UML',
                  onPressed: _showUmlDialog,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.black87),
                  onPressed: () => ref.read(drawingProvider.notifier).undo(),
                ),
                IconButton(
                  icon: const Icon(Icons.redo, color: Colors.black87),
                  onPressed: () => ref.read(drawingProvider.notifier).redo(),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                _buildToolButton(ToolType.pan, Icons.pan_tool),
                _buildToolButton(ToolType.select, Icons.highlight_alt),
                _buildDrawingToolButton(),
                _buildToolButton(ToolType.highlighter, Icons.highlight),
                _buildToolButton(ToolType.eraser, _buildEraserIcon),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white30,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: Icon(
                    Icons.circle,
                    color: ref.watch(drawingProvider).currentColor,
                  ),
                  onPressed: () => _showToolSettingsDialog(),
                ),
              ],
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
      icon = Icons.format_paint;
    else
      icon = Icons.edit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: IconButton(
        icon: Icon(icon, color: isDrawingTool ? Theme.of(context).colorScheme.primary : Colors.black54),
        onPressed: () {
          if (isDrawingTool) {
            _showToolSettingsDialog();
          } else {
            ref.read(drawingProvider.notifier).setTool(ToolType.pen);
          }
        },
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
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
      );
    } else if (iconOrBuilder is Widget Function(bool)) {
      iconWidget = iconOrBuilder(isSelected);
    } else {
      iconWidget = const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: IconButton(
        icon: iconWidget,
        onPressed: () {
          if (isSelected) {
            _showToolSettingsDialog();
          } else {
            ref.read(drawingProvider.notifier).setTool(type);
          }
        },
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
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
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
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.orange,
              Colors.purple,
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
                  const Text(
                    'Stroke Size',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Slider(
                    value: drawingState.currentSize.clamp(
                      1.0,
                      drawingState.currentTool == ToolType.eraser ? 80.0 : 20.0,
                    ),
                    min: 1.0,
                    max: drawingState.currentTool == ToolType.eraser
                        ? 80.0
                        : 20.0,
                    onChanged: (val) {
                      notifier.setSize(val);
                    },
                  ),
                  if (drawingState.currentTool != ToolType.eraser) ...[
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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelectedColor
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
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

  void _showLayoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Insert Layout Position'),
          children: ['Top', 'Bottom', 'Left', 'Right', 'Diagonal', 'Center']
              .map((value) => SimpleDialogOption(
                    onPressed: () {
                      setState(() {
                        _insertionPosition = value;
                      });
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            _insertionPosition == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _insertionPosition == value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(value, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  void _showAnimationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final currentMode = ref.watch(drawingProvider).easterEggMode;
        return SimpleDialog(
          title: const Text('Animations Mode'),
          children: EasterEggMode.values
              .map((value) => SimpleDialogOption(
                    onPressed: () {
                      ref.read(drawingProvider.notifier).setEasterEggMode(value);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            currentMode == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: currentMode == value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            value.name[0].toUpperCase() + value.name.substring(1),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
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

    if (strokes.isNotEmpty) {
      double maxY = double.negativeInfinity;
      double minY = double.infinity;
      double minX = double.infinity;
      double maxX = double.negativeInfinity;

      for (var stroke in strokes) {
        for (var p in stroke.points) {
          double pMaxY = p.dy;
          if (stroke.decodedImage != null) {
            pMaxY += stroke.decodedImage!.height;
          } else if (stroke.text != null)
            pMaxY += (stroke.text!.split('\n').length) * stroke.size * 2.5;
          if (pMaxY > maxY) maxY = pMaxY;
          if (p.dy < minY) minY = p.dy;
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
        }
      }

      if (maxY != double.negativeInfinity) {
        double centerX = minX != double.infinity
            ? (minX + maxX) / 2
            : targetPos.dx;
        double centerY = minY != double.infinity
            ? (minY + maxY) / 2
            : targetPos.dy;

        switch (_insertionPosition) {
          case 'Bottom':
            targetPos = Offset(centerX, maxY + 50);
            break;
          case 'Top':
            targetPos = Offset(
              centerX,
              minY - 300,
            ); // Approximate height, ideally subtract image height
            break;
          case 'Left':
            targetPos = Offset(minX - 400, centerY); // Approximate width
            break;
          case 'Right':
            targetPos = Offset(maxX + 50, centerY);
            break;
          case 'Diagonal':
            targetPos = Offset(maxX + 50, maxY + 50);
            break;
          case 'Center':
            // Keeps targetPos at Viewport Center
            break;
        }
      }
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
