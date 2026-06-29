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
import '../widgets/achievements_dialog.dart';
import '../models/tool_type.dart';
import '../models/page.dart';
import '../models/stroke.dart';
import '../services/plantuml_service.dart';
import 'ai_chat_panel.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  final String notebookId;
  final String pageId;

  const CanvasScreen({super.key, required this.notebookId, required this.pageId});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  late String _currentPageId = widget.pageId;
  bool _isChatOpen = false;
  bool _showToolbox = true;
  String _insertionPosition = 'Bottom';
  final GlobalKey<CanvasWidgetState> _canvasKey = GlobalKey();

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
      backgroundColor: const Color(0xFFFBFBFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
              PopupMenuItem(
                enabled: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          CupertinoIcons.arrow_up_down_square,
                          size: 20,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Insert Layout',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _insertionPosition,
                          isDense: true,
                          iconSize: 18,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _insertionPosition = newValue;
                              });
                              Navigator.pop(context);
                            }
                          },
                          items:
                              <String>[
                                'Top',
                                'Bottom',
                                'Left',
                                'Right',
                                'Diagonal',
                                'Center',
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                enabled: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          CupertinoIcons.wand_stars,
                          size: 20,
                          color: Colors.purple,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Animations',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EasterEggMode>(
                          value: ref.watch(drawingProvider).easterEggMode,
                          isDense: true,
                          iconSize: 18,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (EasterEggMode? newValue) {
                            if (newValue != null) {
                              ref
                                  .read(drawingProvider.notifier)
                                  .setEasterEggMode(newValue);
                              Navigator.pop(context);
                            }
                          },
                          items: EasterEggMode.values
                              .map<DropdownMenuItem<EasterEggMode>>((
                                EasterEggMode value,
                              ) {
                                return DropdownMenuItem<EasterEggMode>(
                                  value: value,
                                  child: Text(
                                    value.name[0].toUpperCase() +
                                        value.name.substring(1),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
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
      body: Stack(
        children: [
          // Infinite Dynamic Background
          Container(
            color:
                ref.watch(drawingProvider).canvasBackgroundColor ??
                Colors.white,
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
                  final bounds = ref.read(drawingProvider).lastAddedBounds;
                  if (bounds != null && _canvasKey.currentState != null) {
                    final matrix =
                        _canvasKey.currentState!.transformationController.value;
                    final scale = matrix.getMaxScaleOnAxis();
                    final size = MediaQuery.of(context).size;

                    final newMatrix = matrix.clone();
                    newMatrix.setTranslationRaw(
                      (size.width / 2) - (bounds.center.dx * scale),
                      (size.height / 2) - (bounds.center.dy * scale),
                      0,
                    );
                    _canvasKey.currentState!.transformationController.value =
                        newMatrix;
                  }
                },
                onDrawEnd: (newMaxY) {
                  setState(() => _isChatOpen = true);
                  final bounds = ref.read(drawingProvider).lastAddedBounds;
                  if (bounds != null && _canvasKey.currentState != null) {
                    final matrix =
                        _canvasKey.currentState!.transformationController.value;
                    final scale = matrix.getMaxScaleOnAxis();
                    final size = MediaQuery.of(context).size;

                    final newMatrix = matrix.clone();
                    // Center the camera precisely on the new drawing
                    newMatrix.setTranslationRaw(
                      (size.width / 2) - (bounds.center.dx * scale),
                      (size.height / 2) - (bounds.center.dy * scale),
                      0,
                    );
                    _canvasKey.currentState!.transformationController.value =
                        newMatrix;
                  }
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
    );
  }

  Widget _buildFloatingDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.white),
                  tooltip: 'Insert Image',
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.paste, color: Colors.white),
                  tooltip: 'Paste Image',
                  onPressed: _pasteImage,
                ),
                IconButton(
                  icon: const Icon(Icons.account_tree, color: Colors.white),
                  tooltip: 'Create UML',
                  onPressed: _showUmlDialog,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white30,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white),
                  onPressed: () => ref.read(drawingProvider.notifier).undo(),
                ),
                IconButton(
                  icon: const Icon(Icons.redo, color: Colors.white),
                  onPressed: () => ref.read(drawingProvider.notifier).redo(),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white30,
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
        icon: Icon(icon, color: isDrawingTool ? Colors.white : Colors.white38),
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
        color: isSelected ? Colors.white : Colors.white38,
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
            color: isSelected ? Colors.white : Colors.white38,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                color: isSelected ? Colors.white : Colors.white38,
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

  Future<void> _pasteImage() async {
    final bytes = await Pasteboard.image;
    if (bytes != null) {
      _insertImageSmart(bytes);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image found in clipboard.')),
      );
    }
  }

  Future<void> _showUmlDialog() async {
    final controller = TextEditingController(
      text:
          'Alice -> Bob: Authentication Request\nBob --> Alice: Authentication Response',
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

class _AiStatusOverlay extends StatelessWidget {
  final String status;
  const _AiStatusOverlay({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status,
          style: GoogleFonts.nanumPenScript(
            textStyle: const TextStyle(color: Colors.black54, fontSize: 28),
          ),
        ),
        const _AnimatedDots(),
      ],
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  _AnimatedDotsState createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
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
        } else if (_controller.value > 0.5)
          dots = "..";
        else if (_controller.value > 0.25)
          dots = ".";

        return SizedBox(
          width: 30,
          child: Text(
            dots,
            style: GoogleFonts.nanumPenScript(
              textStyle: const TextStyle(color: Colors.black54, fontSize: 28),
            ),
          ),
        );
      },
    );
  }
}
