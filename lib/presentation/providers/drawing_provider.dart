import 'package:vinci_board/core/canvas/spatial_index.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/core/models/canvas_command.dart';
import 'package:vinci_board/engines/logic/tesla_engine.dart';
import 'package:vinci_board/engines/logic/components/component_registry.dart';
import 'package:vinci_board/core/models/easter_egg_mode.dart';
import 'package:vinci_board/core/models/canvas_environment.dart';
import 'package:vinci_board/engines/physics/particle_engine.dart';
import 'package:vinci_board/engines/ai/shape_recognizer.dart';
import 'package:vinci_board/presentation/providers/gamification_provider.dart';
import 'package:vinci_board/engines/chemistry/ai/sketch_to_chemistry_ai.dart';
import 'package:vinci_board/engines/math/ai/sketch_to_math_ai.dart';
import 'package:vinci_board/engines/logic/ai/circuit_debugger_ai.dart';
import 'package:vinci_board/engines/logic/study/boolean_algebra_solver.dart';
import 'package:vinci_board/engines/physics/physics_engine.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';
import 'package:vinci_board/core/event_bus.dart';

class TweenData {
  final Rect bounds;
  final double dx;
  final double dy;
  final double scale;
  final double rotation;
  TweenData(this.bounds, this.dx, this.dy, this.scale, this.rotation);
}

class DrawingState {
  final List<Stroke> strokes;
  final List<CanvasCommand> undoHistory;
  final List<CanvasCommand> redoHistory;
  final Color currentColor;
  final double currentSize;
  final ToolType currentTool;
  final List<Stroke> selectedStrokes;
  final List<Stroke>? previewTransformedStrokes;
  final Rect? selectionBounds;
  final Rect? lastAddedBounds;
  final EasterEggMode easterEggMode;
  final CanvasEnvironment canvasEnvironment;
  final EasterEggEffect? activeEffect;
  final DateTime? effectTriggerTime;
  final String? activeEffectMessage;

  final Color? canvasBackgroundColor;
  final String? aiStatus; // Null when not active
  final Offset? aiStatusTarget; // Target position in canvas coordinates
  final bool showGoldenRatio;

  DrawingState({
    this.strokes = const [],
    this.undoHistory = const [],
    this.redoHistory = const [],
    this.currentColor = Colors.black,
    this.currentSize = 2.0,
    this.currentTool = ToolType.pen,
    this.selectedStrokes = const [],
    this.previewTransformedStrokes,
    this.selectionBounds,
    this.lastAddedBounds,
    this.easterEggMode = EasterEggMode.discovery,
    this.canvasEnvironment = CanvasEnvironment.normal,
    this.activeEffect,
    this.effectTriggerTime,
    this.activeEffectMessage,

    this.canvasBackgroundColor = Colors.white,
    this.aiStatus,
    this.aiStatusTarget,
    this.showGoldenRatio = false,
  });

  DrawingState copyWith({
    List<Stroke>? strokes,
    List<CanvasCommand>? undoHistory,
    List<CanvasCommand>? redoHistory,
    Color? currentColor,
    double? currentSize,
    ToolType? currentTool,
    List<Stroke>? selectedStrokes,
    List<Stroke>? previewTransformedStrokes,
    Rect? selectionBounds,
    Rect? lastAddedBounds,
    EasterEggMode? easterEggMode,
    CanvasEnvironment? canvasEnvironment,
    EasterEggEffect? activeEffect,
    DateTime? effectTriggerTime,
    String? activeEffectMessage,

    bool clearSelection = false,
    bool clearPreview = false,
    bool clearLastAdded = false,
    bool clearEasterEgg = false,
    Color? canvasBackgroundColor,
    String? aiStatus,
    Offset? aiStatusTarget,
    bool clearAiStatus = false,
    bool? showGoldenRatio,
  }) {
    return DrawingState(
      strokes: strokes ?? this.strokes,
      undoHistory: undoHistory ?? this.undoHistory,
      redoHistory: redoHistory ?? this.redoHistory,
      currentColor: currentColor ?? this.currentColor,
      currentSize: currentSize ?? this.currentSize,
      currentTool: currentTool ?? this.currentTool,
      selectedStrokes: clearSelection
          ? []
          : (selectedStrokes ?? this.selectedStrokes),
      previewTransformedStrokes: clearPreview
          ? null
          : (previewTransformedStrokes ?? this.previewTransformedStrokes),
      selectionBounds: clearSelection
          ? null
          : (selectionBounds ?? this.selectionBounds),
      lastAddedBounds: clearLastAdded
          ? null
          : (lastAddedBounds ?? this.lastAddedBounds),
      easterEggMode: easterEggMode ?? this.easterEggMode,
      canvasEnvironment: canvasEnvironment ?? this.canvasEnvironment,
      activeEffect: clearEasterEgg ? null : (activeEffect ?? this.activeEffect),
      effectTriggerTime: clearEasterEgg
          ? null
          : (effectTriggerTime ?? this.effectTriggerTime),
      activeEffectMessage: clearEasterEgg
          ? null
          : (activeEffectMessage ?? this.activeEffectMessage),
      canvasBackgroundColor:
          canvasBackgroundColor ?? this.canvasBackgroundColor,
      aiStatus: clearAiStatus ? null : (aiStatus ?? this.aiStatus),
      aiStatusTarget: clearAiStatus
          ? null
          : (aiStatusTarget ?? this.aiStatusTarget),
      showGoldenRatio: showGoldenRatio ?? this.showGoldenRatio,
    );
  }
}

class DrawingNotifier extends Notifier<DrawingState> {
  late final ValueNotifier<Stroke?> activeStrokeNotifier;
  final SpatialIndex _spatialIndex = SpatialIndex();
  SpatialIndex get spatialIndex => _spatialIndex;

  @override
  DrawingState build() {
    PhysicsEngine().init(ref.read(eventBusProvider));
    activeStrokeNotifier = ValueNotifier<Stroke?>(null);
    ref.onDispose(() {
      activeStrokeNotifier.dispose();
      _physicsTimer?.cancel();
      PhysicsEngine().stopSimulation();
      // Dispose all images on unmount
      for (var stroke in state.strokes) {
        stroke.decodedImage?.dispose();
      }
    });
    return DrawingState();
  }

  @override
  set state(DrawingState value) {
    final oldStrokes = super.state.strokes;
    final newStrokes = value.strokes;

    // Only do expensive spatial index / disposal work when strokes actually changed
    if (!identical(oldStrokes, newStrokes)) {
      // 1. Detect removed strokes to handle memory leaks (ui.Image disposal)
      if (oldStrokes.length > newStrokes.length) {
        final newIds = newStrokes.map((s) => s.id).toSet();
        for (var oldStroke in oldStrokes) {
          if (!newIds.contains(oldStroke.id)) {
            oldStroke.decodedImage?.dispose();
          }
        }
      }

      // 2. Rebuild the spatial index only when strokes changed
      _spatialIndex.buildIndex(newStrokes);
    }

    super.state = value;
  }

  static List<Stroke> clipboard = [];
  Stroke? _currentStroke;
  Timer? _physicsTimer;
  bool _isWarningDismissed = false;
  final Set<String> _completedComponentIds = {};

  void _startPhysicsLoop() {
    if (_physicsTimer?.isActive ?? false) {
      return; // Keep flag to avoid multiple starts
    }

    final physics = PhysicsEngine();

    // Subscribe to engine ticks
    physics.onPhysicsUpdate = (updatedStrokes) {
      // Update strokes in the state based on physics positions
      state = state.copyWith(strokes: updatedStrokes);
    };

    // Attach all physics-enabled strokes to the engine
    physics.attachStrokes(state.strokes);
    physics.startSimulation();

    // Just run a small timer to monitor if physics stopped, so we can clean up
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      bool hasActivePhysics = state.strokes.any((s) => s.physicsEnabled);
      if (!hasActivePhysics) {
        physics.stopSimulation();
        _physicsTimer?.cancel();
      }
    });
  }

  void toggleGoldenRatio() {
    state = state.copyWith(showGoldenRatio: !state.showGoldenRatio);
  }

  /// Enable physics on all strokes belonging to [groupId] and start simulation.
  void applyGravityToGroup(String groupId) {
    final newStrokes = state.strokes.map((s) {
      if (s.groupId == groupId || s.id == groupId || s.name == groupId) {
        return s.copyWith(physicsEnabled: true, velocity: Offset.zero);
      }
      return s;
    }).toList();
    _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    _startPhysicsLoop();
  }

  /// Enable physics on specific strokes by their IDs.
  void applyGravityToStrokes(List<String> ids) {
    final newStrokes = state.strokes.map((s) {
      if (ids.contains(s.id) ||
          (s.groupId != null && ids.contains(s.groupId))) {
        return s.copyWith(physicsEnabled: true, velocity: Offset.zero);
      }
      return s;
    }).toList();
    _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    _startPhysicsLoop();
  }

  void applyAnimationToStrokes(List<String> ids, String animationType) {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final newStrokes = state.strokes.map((s) {
      if (ids.contains(s.id) ||
          (s.groupId != null && ids.contains(s.groupId))) {
        return s.copyWith(
          animationType: animationType,
          animationProgress: now,
          physicsEnabled: false, // Turn off physics to prevent visual conflicts
        );
      }
      return s;
    }).toList();
    _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
  }

  void stopSimulation() {
    final List<Stroke> newStrokes = state.strokes.map<Stroke>((s) {
      if (s.physicsEnabled || s.animationType != null) {
        return s.copyWith(
          physicsEnabled: false,
          velocity: Offset.zero,
          clearAnimationType: true,
        );
      }
      return s;
    }).toList();
    _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    PhysicsEngine().stopSimulation();
  }

  void selectAll() {
    if (state.strokes.isEmpty) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var stroke in state.strokes) {
      if (stroke.bounds.left < minX) minX = stroke.bounds.left;
      if (stroke.bounds.top < minY) minY = stroke.bounds.top;
      if (stroke.bounds.right > maxX) maxX = stroke.bounds.right;
      if (stroke.bounds.bottom > maxY) maxY = stroke.bounds.bottom;
    }

    state = state.copyWith(
      selectedStrokes: List.from(state.strokes),
      selectionBounds: Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  void selectStrokesInRect(Rect rect) {
    List<Stroke> selected = _spatialIndex.queryRect(rect);
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    if (selected.isEmpty) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    for (var stroke in selected) {
      if (stroke.bounds.left < minX) minX = stroke.bounds.left;
      if (stroke.bounds.top < minY) minY = stroke.bounds.top;
      if (stroke.bounds.right > maxX) maxX = stroke.bounds.right;
      if (stroke.bounds.bottom > maxY) maxY = stroke.bounds.bottom;
    }
    Rect? bounds;
    for (var s in selected) {
      bounds = bounds == null ? s.bounds : bounds.expandToInclude(s.bounds);
    }

    // Lock newly selected strokes
    final selectedIds = selected.map((s) => s.id).toSet();
    final newStrokes = state.strokes.map((s) {
      if (selectedIds.contains(s.id)) return s.copyWith(isLocked: true);
      return s;
    }).toList();

    state = state.copyWith(
      strokes: newStrokes,
      selectedStrokes: selected.map((s) => s.copyWith(isLocked: true)).toList(),
      selectionBounds: bounds,
    );
  }

  void clearSelection() {
    if (state.selectedStrokes.isNotEmpty) {
      final oldIds = state.selectedStrokes.map((s) => s.id).toSet();
      final newStrokes = state.strokes.map((s) {
        if (oldIds.contains(s.id)) return s.copyWith(isLocked: false);
        return s;
      }).toList();
      state = state.copyWith(strokes: newStrokes, clearSelection: true, clearPreview: true);
    }
  }

  void setEasterEggMode(EasterEggMode mode) {
    state = state.copyWith(easterEggMode: mode, clearEasterEgg: true);
  }

  void clearEasterEgg() {
    state = state.copyWith(clearEasterEgg: true);
  }

  void addStroke(Stroke stroke) {
    _isWarningDismissed = false;
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _updateSimulationAndAi();
  }

  String placeText(String text, Offset position) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    addStroke(
      Stroke(
        id: id,
        points: [position],
        color: state.currentColor,
        size: 18.0,
        toolType: ToolType.text,
        text: text,
      ),
    );
    return id;
  }

  void clearCanvas() {
    _completedComponentIds.clear();
    state = state.copyWith(
      strokes: [],
      undoHistory: [],
      clearSelection: true,
      clearAiStatus: true,
    );
    TeslaEngine().clear();
  }

  void setCanvasEnvironment(CanvasEnvironment env) {
    state = state.copyWith(canvasEnvironment: env);
  }

  void _checkEasterEggs(String text) {
    if (state.easterEggMode != EasterEggMode.discovery) return;

    final lower = text.toLowerCase();
    EasterEggEffect? effect;
    CanvasEnvironment? env;
    if (lower.contains('rain')) {
      effect = EasterEggEffect.rain;
    } else if (lower.contains('done'))
      effect = EasterEggEffect.done;
    else if (lower.contains('fire')) {
      effect = EasterEggEffect.fire;
      env = CanvasEnvironment.warm;
    } else if (lower.contains('snow')) {
      effect = EasterEggEffect.snow;
      env = CanvasEnvironment.frozen;
    } else if (lower.contains('love') || lower.contains('❤️')) {
      effect = EasterEggEffect.love;
    } else if (lower.contains('black hole') || lower.contains('blackhole')) {
      effect = EasterEggEffect.blackHole;
    } else if (lower.contains('clear')) {
      env = CanvasEnvironment.normal; // typing "clear" resets env
    }

    if (effect != null || env != null) {
      if (effect != null && effect != EasterEggEffect.none) {
        ref.read(gamificationProvider.notifier).unlockAchievement(effect.name);
      }
      state = state.copyWith(
        activeEffect: effect ?? state.activeEffect,
        effectTriggerTime: effect != null
            ? DateTime.now()
            : state.effectTriggerTime,
        canvasEnvironment: env ?? state.canvasEnvironment,
      );
    }
  }

  void triggerEasterEgg(String effectName) {
    _checkEasterEggs(effectName);
  }

  void transformSelection(double dx, double dy, double scale, double rotation) {
    if (state.selectedStrokes.isEmpty || state.selectionBounds == null) return;

    final center = state.selectionBounds!.center;
    final List<Stroke> transformed = [];

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var stroke in state.selectedStrokes) {
      final newPoints = stroke.points.map((p) {
        double translatedX = p.dx - center.dx;
        double translatedY = p.dy - center.dy;

        if (rotation != 0.0) {
          final double cosR = math.cos(rotation);
          final double sinR = math.sin(rotation);
          final double rx = translatedX * cosR - translatedY * sinR;
          final double ry = translatedX * sinR + translatedY * cosR;
          translatedX = rx;
          translatedY = ry;
        }

        if (scale != 1.0) {
          translatedX *= scale;
          translatedY *= scale;
        }

        translatedX += center.dx + dx;
        translatedY += center.dy + dy;

        if (translatedX < minX) minX = translatedX;
        if (translatedY < minY) minY = translatedY;
        if (translatedX > maxX) maxX = translatedX;
        if (translatedY > maxY) maxY = translatedY;

        return Offset(translatedX, translatedY);
      }).toList();

      final newStroke = Stroke(
        points: newPoints,
        color: stroke.color,
        size: stroke.size * scale,
        rotation: stroke.rotation + rotation,
        toolType: stroke.toolType,
        text: stroke.text,
        imageBytes: stroke.imageBytes,
        decodedImage: stroke.decodedImage,
      );

      final bounds = newStroke.bounds;
      if (bounds.left < minX) minX = bounds.left;
      if (bounds.top < minY) minY = bounds.top;
      if (bounds.right > maxX) maxX = bounds.right;
      if (bounds.bottom > maxY) maxY = bounds.bottom;

      transformed.add(newStroke);
    }

    state = state.copyWith(
      selectionBounds: Rect.fromLTRB(minX, minY, maxX, maxY),
      previewTransformedStrokes: transformed,
    );
  }

  void deleteSelection() {
    if (state.selectedStrokes.isEmpty) return;
    _isWarningDismissed = false;
    final remaining = state.strokes
        .where((s) => !state.selectedStrokes.contains(s))
        .toList();

    state = state.copyWith(
      strokes: remaining,
      clearSelection: true,
      clearPreview: true,
    );
  }

  void copySelection() {
    if (state.selectedStrokes.isEmpty) return;

    // Push text to OS clipboard so it can be pasted outside the app
    final textStrokes = state.selectedStrokes
        .where((s) => s.text != null && s.text!.isNotEmpty)
        .toList();
    if (textStrokes.isNotEmpty) {
      final combinedText = textStrokes.map((s) => s.text!).join('\n');
      Clipboard.setData(ClipboardData(text: combinedText));
    }

    clipboard = state.selectedStrokes.map((s) {
      return Stroke(
        points: s.points.map((p) => Offset(p.dx, p.dy)).toList(),
        color: s.color,
        size: s.size,
        toolType: s.toolType,
        text: s.text,
        decodedImage: s.decodedImage,
        imageBytes: s.imageBytes,
      );
    }).toList();
  }

  void cutSelection() {
    if (state.selectedStrokes.isEmpty) return;
    copySelection();
    deleteSelection();
  }

  bool pasteFromClipboard() {
    if (clipboard.isEmpty) return false;

    final List<Stroke> pasted = clipboard.map((s) {
      return Stroke(
        points: s.points.map((p) => Offset(p.dx + 20, p.dy + 20)).toList(),
        color: s.color,
        size: s.size,
        toolType: s.toolType,
        text: s.text,
        decodedImage: s.decodedImage,
        imageBytes: s.imageBytes,
      );
    }).toList();

    // Update clipboard to offset again for next paste
    clipboard = pasted;

    state = state.copyWith(
      strokes: [...state.strokes, ...pasted],
      selectedStrokes: pasted,
      clearPreview: true,
      selectionBounds: state.selectionBounds?.translate(20, 20),
    );
    return true;
  }

  void duplicateSelection() {
    if (state.selectedStrokes.isEmpty) return;

    // Create duplicated strokes offset by 20 pixels
    final List<Stroke> duplicates = state.selectedStrokes.map((s) {
      return Stroke(
        points: s.points.map((p) => Offset(p.dx + 20, p.dy + 20)).toList(),
        color: s.color,
        size: s.size,
        toolType: s.toolType,
        text: s.text,
        decodedImage: s.decodedImage,
        imageBytes: s.imageBytes,
      );
    }).toList();

    state = state.copyWith(
      strokes: [...state.strokes, ...duplicates],
      selectedStrokes: duplicates, // Select the new duplicates
      clearPreview: true,
      selectionBounds: state.selectionBounds?.translate(20, 20),
    );
  }

  void commitSelectionTransform() {
    if (state.previewTransformedStrokes == null ||
        state.selectedStrokes.isEmpty) {
      return;
    }

    final List<Stroke> newStrokes = List.from(state.strokes);
    for (int i = 0; i < state.selectedStrokes.length; i++) {
      final oldStroke = state.selectedStrokes[i];
      final newStroke = state.previewTransformedStrokes![i];
      final idx = newStrokes.indexOf(oldStroke);
      if (idx != -1) {
        newStrokes[idx] = newStroke;
      }
    }

    state = state.copyWith(
      strokes: newStrokes,
      selectedStrokes: state.previewTransformedStrokes!,
      clearPreview: true,
    );
    _updateSimulationAndAi();
  }

  void startStroke(Offset position) {
    _currentStroke = Stroke(
      points: [position],
      color: state.currentTool == ToolType.eraser
          ? Colors.transparent
          : state.currentColor,
      size: state.currentTool == ToolType.wire ? 4.0 : state.currentSize,
      toolType: state.currentTool,
      isFilled: state.currentTool == ToolType.fill,
    );
    activeStrokeNotifier.value = _currentStroke;
  }

  void updateStroke(Offset position) {
    if (_currentStroke == null) return;

    final updatedPoints = List<Offset>.from(_currentStroke!.points)
      ..add(position);

    _currentStroke = _currentStroke!.copyWith(points: updatedPoints);
    activeStrokeNotifier.value = _currentStroke;
  }

  void endStroke() {
    if (_currentStroke == null || _currentStroke!.points.isEmpty) return;
    _isWarningDismissed = false;
    final oldStrokes = List<Stroke>.from(state.strokes);
    state = state.copyWith(strokes: [...state.strokes, _currentStroke!]);

    if (state.currentTool == ToolType.fill &&
        _currentStroke!.points.length < 5) {
      // It was a tap! Execute bucket fill logic
      final tapPoint = _currentStroke!.points.first;
      // Remove the tiny dot stroke we just added during the tap
      final newStrokes = List<Stroke>.from(state.strokes)..removeLast();
      state = state.copyWith(strokes: newStrokes);

      _executeBucketFill(tapPoint);
      _currentStroke = null;
      activeStrokeNotifier.value = null;
      return;
    }

    if (state.currentTool == ToolType.eraser) {
      // For a pixel eraser (like Photoshop), we MUST keep the eraser stroke itself
      // on the canvas so it can be rendered with BlendMode.clear.
      // We only delete intersecting widgets.
      final newStrokes = _executeWidgetErasureAndGetStrokes();
      _commitCommand(SnapshotCommand(oldStrokes, newStrokes));

      _currentStroke = null;
      activeStrokeNotifier.value = null;
      return;
    }

    if (state.currentTool == ToolType.wire &&
        _currentStroke!.points.length > 2) {
      final startPoint = _currentStroke!.points.first;
      final endPoint = _currentStroke!.points.last;

      Stroke? sourceStroke;
      Stroke? targetStroke;
      String? sourcePinId;
      String? targetPinId;

      double minSourceDist = double.infinity;
      double minTargetDist = double.infinity;
      for (var s in state.strokes.take(state.strokes.length - 1)) {
        final comp = ComponentRegistry().createComponent(s);
        if (comp != null) {
          if (comp.pins.isNotEmpty) {
            final center = s.bounds.center;
            for (var pin in comp.pins) {
              final pinPos = center + pin.relativePosition;

              final startDist = (pinPos - startPoint).distance;
              if (startDist < minSourceDist) {
                if (startDist < 100 ||
                    s.bounds.inflate(20).contains(startPoint)) {
                  minSourceDist = startDist;
                  sourceStroke = s;
                  sourcePinId = pin.id;
                }
              }

              final endDist = (pinPos - endPoint).distance;
              if (endDist < minTargetDist) {
                if (endDist < 100 || s.bounds.inflate(20).contains(endPoint)) {
                  minTargetDist = endDist;
                  targetStroke = s;
                  targetPinId = pin.id;
                }
              }
            }
          } else {
            // Portals or other pin-less components
            final center = s.bounds.center;
            final startDist = (center - startPoint).distance;
            if (startDist < minSourceDist &&
                (startDist < 100 ||
                    s.bounds.inflate(40).contains(startPoint))) {
              minSourceDist = startDist;
              sourceStroke = s;
              sourcePinId = null;
            }

            final endDist = (center - endPoint).distance;
            if (endDist < minTargetDist &&
                (endDist < 100 || s.bounds.inflate(40).contains(endPoint))) {
              minTargetDist = endDist;
              targetStroke = s;
              targetPinId = null;
            }
          }
        }
      }

      if (sourceStroke != null && targetStroke != null) {
        if (sourceStroke.toolType == ToolType.portal &&
            targetStroke.toolType == ToolType.portal) {
          final newStrokes = List<Stroke>.from(state.strokes)..removeLast();

          Stroke copyStrokeWithMeta(Stroke s, String destinationId) {
            return Stroke(
              id: s.id,
              groupId: s.groupId,
              name: s.name,
              points: s.points,
              color: s.color,
              size: s.size,
              rotation: s.rotation,
              toolType: s.toolType,
              text: s.text,
              imageBytes: s.imageBytes,
              decodedImage: s.decodedImage,
              isFilled: s.isFilled,
              semanticMeaning: s.semanticMeaning,
              physicsEnabled: s.physicsEnabled,
              customMetadata: {
                ...(s.customMetadata ?? {}),
                'destinationId': destinationId,
              },
              version: s.version + 1,
            );
          }

          final newSource = copyStrokeWithMeta(sourceStroke, targetStroke.id);
          final newTarget = copyStrokeWithMeta(targetStroke, sourceStroke.id);

          final sourceIndex = newStrokes.indexWhere(
            (s) => s.id == sourceStroke!.id,
          );
          if (sourceIndex != -1) newStrokes[sourceIndex] = newSource;

          final targetIndex = newStrokes.indexWhere(
            (s) => s.id == targetStroke!.id,
          );
          if (targetIndex != -1) newStrokes[targetIndex] = newTarget;

          state = state.copyWith(strokes: TeslaEngine.updateWires(newStrokes));
          _currentStroke = null;
        } else {
          final newMeta = {...(_currentStroke!.customMetadata ?? {})};
          newMeta['sourceId'] = sourceStroke.id;
          newMeta['targetId'] = targetStroke.id;
          newMeta['sourcePinId'] = sourcePinId;
          newMeta['targetPinId'] = targetPinId;

          final correctedWire = Stroke(
            id: _currentStroke!.id,
            groupId: _currentStroke!.groupId,
            name: _currentStroke!.name,
            points: _currentStroke!.points,
            color: _currentStroke!.color,
            size: _currentStroke!.size,
            rotation: _currentStroke!.rotation,
            toolType: ToolType.wire,
            text: _currentStroke!.text,
            imageBytes: _currentStroke!.imageBytes,
            decodedImage: _currentStroke!.decodedImage,
            isFilled: _currentStroke!.isFilled,
            semanticMeaning: _currentStroke!.semanticMeaning,
            physicsEnabled: _currentStroke!.physicsEnabled,
            customMetadata: newMeta,
            version: _currentStroke!.version + 1,
          );
          final newStrokes = List<Stroke>.from(state.strokes);
          newStrokes.last = correctedWire;
          state = state.copyWith(strokes: newStrokes);
          _currentStroke = correctedWire;
        }
      }
    }

    // Calculate Bounds
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var p in _currentStroke!.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    Rect currentBounds = Rect.fromLTRB(minX, minY, maxX, maxY);

    ref.read(gamificationProvider.notifier).addXp(5);

    // Shape auto-correction: try to recognise circle / star / spiral / hexagon
    final recognized = ShapeRecognizer.recognize(_currentStroke!.points);
    if (recognized != ShapeType.unknown) {
      if (state.canvasEnvironment == CanvasEnvironment.chemistry) {
        final chemistryAi = SketchToChemistryAi();
        final aiResult = chemistryAi.analyzeSketch(_currentStroke!.points);
        if (aiResult['confidence'] > 0.8) {
          final chemStroke = Stroke(
            id: _currentStroke!.id,
            points: _currentStroke!.points,
            color: _currentStroke!.color,
            size: _currentStroke!.size,
            toolType: ToolType.pen,
            smiles:
                "Benzene", // We use name instead of SMILES so PubChem 'name' endpoint works
            customMetadata: {
              ...(_currentStroke!.customMetadata ?? {}),
              'ai_detected': true,
              'name': aiResult['detectedStructure'],
            },
          );
          final correctedStrokes = List<Stroke>.from(state.strokes);
          correctedStrokes.last = chemStroke;
          state = state.copyWith(strokes: correctedStrokes);
          _currentStroke = chemStroke;
          ref
              .read(gamificationProvider.notifier)
              .unlockAchievement('chemistry_master');
        }
      } else {
        final perfectPoints = ShapeRecognizer.generatePerfectShape(
          recognized,
          _currentStroke!.points,
        );
        if (perfectPoints.isNotEmpty) {
          final corrected = Stroke(
            id: _currentStroke!.id,
            points: perfectPoints,
            color: _currentStroke!.color,
            size: _currentStroke!.size,
            toolType: _currentStroke!.toolType,
            isFilled: _currentStroke!.isFilled,
            customMetadata: _currentStroke!.customMetadata,
          );
          // Replace the last stroke with the corrected one
          final correctedStrokes = List<Stroke>.from(state.strokes);
          correctedStrokes.last = corrected;
          state = state.copyWith(strokes: correctedStrokes);
          _currentStroke = corrected;
          // Award the achievement for the first successful correction
          ref
              .read(gamificationProvider.notifier)
              .unlockAchievement('shape_master');
        }
      }
    }

    // Phase 3: Sketch-to-Math AI Hook
    if (_currentStroke!.toolType == ToolType.latex) {
      final mathAi = SketchToMathAi();
      final aiResult = mathAi.analyzeSketch(_currentStroke!.points);
      if (aiResult['confidence'] > 0.8) {
        // If the AI says it's a graphable equation, spawn a graph widget!
        if (aiResult['suggestedAction'] == 'Graph Function') {
          final mathStroke = Stroke(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            toolType: ToolType.widget,
            points: _currentStroke!.points
                .map((p) => Offset(p.dx, p.dy + 50))
                .toList(),
            color: Colors.black,
            size: 1.0,
            text:
                '{"type": "graph", "expression": "${aiResult['mathExpression']}"}',
          );
          final correctedStrokes = List<Stroke>.from(state.strokes);
          correctedStrokes.add(mathStroke);
          state = state.copyWith(strokes: correctedStrokes);
        }
      }
    }

    if (maxX != double.negativeInfinity) {
      state = state.copyWith(lastAddedBounds: currentBounds);
    }
    _commitCommand(SnapshotCommand(oldStrokes, state.strokes));
    _currentStroke = null;
    activeStrokeNotifier.value = null;
    _updateSimulationAndAi();
  }

  void _executeBucketFill(Offset point) {
    final candidates = _spatialIndex.queryPoint(point);
    if (candidates.isEmpty) return;
    final candidateSet = candidates.map((s) => s.id).toSet();

    // Search from top to bottom (reverse order) so we fill the front-most shape
    for (int i = state.strokes.length - 1; i >= 0; i--) {
      final stroke = state.strokes[i];
      if (!candidateSet.contains(stroke.id)) continue;

      if (stroke.points.isEmpty ||
          stroke.toolType == ToolType.latex ||
          stroke.toolType == ToolType.widget) {
        continue;
      }

      if (stroke.path.contains(point)) {
        final filledStroke = stroke.copyWith(
          isFilled: true,
          toolType: ToolType.pen,
          color: state.currentColor,
        );

        final newStrokes = List<Stroke>.from(state.strokes);
        newStrokes.insert(i, filledStroke);

        _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
        return;
      }
    }
  }

  void undo() {
    if (state.undoHistory.isEmpty) return;

    final newUndoHistory = List<CanvasCommand>.from(state.undoHistory);
    final lastCommand = newUndoHistory.removeLast();

    final newStrokes = List<Stroke>.from(state.strokes);
    lastCommand.undo(newStrokes);

    final newRedoHistory = List<CanvasCommand>.from(state.redoHistory)
      ..add(lastCommand);

    _spatialIndex.buildIndex(newStrokes);
    state = state.copyWith(
      strokes: newStrokes,
      undoHistory: newUndoHistory,
      redoHistory: newRedoHistory,
    );
    _updateSimulationAndAi();
  }

  void redo() {
    if (state.redoHistory.isEmpty) return;

    final newRedoHistory = List<CanvasCommand>.from(state.redoHistory);
    final nextCommand = newRedoHistory.removeLast();

    final newStrokes = List<Stroke>.from(state.strokes);
    nextCommand.execute(newStrokes);

    final newUndoHistory = List<CanvasCommand>.from(state.undoHistory)
      ..add(nextCommand);

    if (newUndoHistory.length > 50) newUndoHistory.removeAt(0);

    _spatialIndex.buildIndex(newStrokes);
    state = state.copyWith(
      strokes: newStrokes,
      undoHistory: newUndoHistory,
      redoHistory: newRedoHistory,
    );
    _updateSimulationAndAi();
  }

  void _commitCommand(CanvasCommand cmd) {
    final newStrokes = List<Stroke>.from(state.strokes);
    cmd.execute(newStrokes);
    final newUndo = List<CanvasCommand>.from(state.undoHistory)..add(cmd);
    if (newUndo.length > 50) newUndo.removeAt(0);
    _spatialIndex.buildIndex(newStrokes);
    state = state.copyWith(
      strokes: newStrokes,
      undoHistory: newUndo,
      redoHistory: [],
    );
  }

  void clear() {
    if (state.strokes.isNotEmpty) {
      _commitCommand(ClearCanvasCommand(List.from(state.strokes)));
    }
  }

  void eraseText(String textToErase) {
    if (state.strokes.isEmpty) return;

    final lowercased = textToErase.toLowerCase();
    final toRemove = state.strokes.where((stroke) {
      if (stroke.text != null) {
        return stroke.text!.toLowerCase().contains(lowercased);
      }
      return false;
    }).toList();

    if (toRemove.isNotEmpty) {
      _commitCommand(RemoveStrokesCommand(toRemove));
      _updateSimulationAndAi();
    }
  }

  void eraseStrokes(List<Stroke> strokesToRemove) {
    if (strokesToRemove.isEmpty) return;
    _commitCommand(RemoveStrokesCommand(strokesToRemove));
    _updateSimulationAndAi();
  }

  void loadStrokes(List<Stroke> strokes) async {
    state = state.copyWith(
      strokes: strokes,
      undoHistory: [],
      clearAiStatus: true,
    );
    // Decode any images in the loaded strokes asynchronously
    bool updated = false;
    for (var stroke in strokes) {
      if (stroke.imageBytes != null && stroke.decodedImage == null) {
        final decoded = await decodeImageFromList(stroke.imageBytes!);
        stroke.decodedImage = decoded;
        updated = true;
      }
    }
    if (updated) {
      // Force repaint by assigning a new list
      state = state.copyWith(strokes: List.from(strokes));
    }
    _updateSimulationAndAi();
  }

  Future<void> insertImage(Uint8List bytes, Offset position) async {
    // Decode the image first to check its natural size
    ui.Image decodedImage = await decodeImageFromList(bytes);

    // Scale down huge images to prevent them from taking up the entire infinite canvas
    if (decodedImage.width > 800 || decodedImage.height > 800) {
      int targetWidth = decodedImage.width;
      int targetHeight = decodedImage.height;

      if (decodedImage.width > decodedImage.height) {
        targetWidth = 800;
        targetHeight = (800 / decodedImage.width * decodedImage.height).round();
      } else {
        targetHeight = 800;
        targetWidth = (800 / decodedImage.height * decodedImage.width).round();
      }

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      decodedImage = frame.image;
    }

    if (state.easterEggMode != EasterEggMode.focus) {
      // Bouncy Paste Animation!
      state = state.copyWith(
        strokes: [
          ...state.strokes,
          Stroke(
            points: [position],
            color: Colors.transparent,
            size: 0.1,
            toolType: ToolType.pan,
            imageBytes: bytes,
            decodedImage: decodedImage,
          ),
        ],
        lastAddedBounds: Rect.fromLTWH(
          position.dx,
          position.dy,
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        ),
      );

      final scales = [0.2, 0.5, 0.9, 1.15, 0.95, 1.05, 1.0];
      for (var s in scales) {
        await Future.delayed(const Duration(milliseconds: 24));
        final updatedStrokes = List<Stroke>.from(state.strokes);
        updatedStrokes.last = Stroke(
          points: [position],
          color: Colors.transparent,
          size: s,
          toolType: ToolType.pan,
          imageBytes: bytes,
          decodedImage: decodedImage,
        );
        state = state.copyWith(strokes: updatedStrokes);
      }
    } else {
      final imageStroke = Stroke(
        points: [position],
        color: Colors.transparent,
        size: 1.0,
        toolType: ToolType.pan,
        imageBytes: bytes,
        decodedImage: decodedImage,
      );

      state = state.copyWith(
        strokes: [...state.strokes, imageStroke],
        lastAddedBounds: Rect.fromLTWH(
          position.dx,
          position.dy,
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        ),
      );
    }
  }

  void addStrokes(List<Stroke> newStrokes) {
    if (newStrokes.isEmpty) return;
    _isWarningDismissed = false;

    _commitCommand(AddStrokesCommand(newStrokes));

    Rect? combinedBounds;
    for (final stroke in newStrokes) {
      final b = stroke.bounds;
      combinedBounds = combinedBounds == null
          ? b
          : combinedBounds.expandToInclude(b);
    }
    if (combinedBounds != null) {
      state = state.copyWith(lastAddedBounds: combinedBounds);
    }
    _updateSimulationAndAi();
  }

  void moveLastStrokes(int count, Offset offset) {
    if (state.strokes.isEmpty || count <= 0) return;

    final newStrokes = List<Stroke>.from(state.strokes);
    final countToMove = count.clamp(0, newStrokes.length);

    for (int i = newStrokes.length - countToMove; i < newStrokes.length; i++) {
      final stroke = newStrokes[i];
      final newPoints = stroke.points.map((p) => p + offset).toList();

      // Need a way to copy with new points. Since Stroke doesn't have copyWith, we create a new one.
      newStrokes[i] = Stroke(
        points: newPoints,
        color: stroke.color,
        size: stroke.size,
        rotation: stroke.rotation,
        toolType: stroke.toolType,
        imageBytes: stroke.imageBytes,
        decodedImage: stroke.decodedImage,
        text: stroke.text,
      );
    }

    state = state.copyWith(strokes: newStrokes);
  }

  void transformStrokesInRect(
    Rect bounds, {
    double dx = 0,
    double dy = 0,
    double scale = 1.0,
    double rotation = 0.0,
  }) {
    if (state.strokes.isEmpty) return;
    final newStrokes = List<Stroke>.from(state.strokes);

    bool madeChanges = false;

    for (int i = 0; i < newStrokes.length; i++) {
      final stroke = newStrokes[i];

      final bounds = stroke.bounds;
      final sMinX = bounds.left;
      final sMinY = bounds.top;
      final sMaxX = bounds.right;
      final sMaxY = bounds.bottom;

      // Pad the stroke bounds slightly to make selection forgiving
      final strokeRect = Rect.fromLTRB(
        sMinX - 10,
        sMinY - 10,
        sMaxX + 10,
        sMaxY + 10,
      );
      bool intersects = strokeRect.overlaps(bounds);

      if (intersects) {
        madeChanges = true;
        // Find center of the stroke for rotation/scaling
        final center = Offset((sMinX + sMaxX) / 2, (sMinY + sMaxY) / 2);

        final newPoints = stroke.points.map((p) {
          double translatedX = p.dx - center.dx;
          double translatedY = p.dy - center.dy;

          if (rotation != 0.0) {
            final double cosR = math.cos(rotation);
            final double sinR = math.sin(rotation);
            final double rx = translatedX * cosR - translatedY * sinR;
            final double ry = translatedX * sinR + translatedY * cosR;
            translatedX = rx;
            translatedY = ry;
          }

          if (scale != 1.0) {
            translatedX *= scale;
            translatedY *= scale;
          }

          return Offset(
            translatedX + center.dx + dx,
            translatedY + center.dy + dy,
          );
        }).toList();

        newStrokes[i] = Stroke(
          points: newPoints,
          color: stroke.color,
          size: stroke.size * scale,
          toolType: stroke.toolType,
          imageBytes: stroke.imageBytes,
          decodedImage: stroke.decodedImage,
          text: stroke.text,
        );
      }
    }

    if (madeChanges) {
      state = state.copyWith(strokes: newStrokes);
    }
  }

  void removeStrokes(List<Stroke> strokesToRemove) {
    if (strokesToRemove.isEmpty) return;

    final currentStrokes = List<Stroke>.from(state.strokes);
    currentStrokes.removeWhere((s) => strokesToRemove.contains(s));

    state = state.copyWith(strokes: currentStrokes);
  }

  Future<void> animateStrokes(List<Stroke> newStrokes) async {
    if (newStrokes.isEmpty) return;

    // Wait for the camera to pan to the location BEFORE drawing
    await Future.delayed(const Duration(milliseconds: 600));

    // Create a copy of the list and sort it from top to bottom (Y coordinate)
    // This ensures the animation feels like someone writing naturally down a page!
    final sortedStrokes = List<Stroke>.from(newStrokes);
    sortedStrokes.sort((a, b) {
      final aY = a.points.isNotEmpty ? a.points.first.dy : 0.0;
      final bY = b.points.isNotEmpty ? b.points.first.dy : 0.0;
      return aY.compareTo(bY);
    });

    for (var stroke in sortedStrokes) {
      if (stroke.points.isEmpty) {
        state = state.copyWith(
          strokes: [...state.strokes, stroke],
          undoHistory: state.undoHistory, // Keep history intact
        );
        continue;
      }
      if (stroke.text != null &&
          stroke.toolType != ToolType.latex &&
          stroke.toolType != ToolType.widget &&
          stroke.smiles == null) {
        final fullText = stroke.text!;
        _checkEasterEggs(fullText);

        final initialStroke = stroke.copyWith(
          text: "", // Start empty
        );
        state = state.copyWith(strokes: [...state.strokes, initialStroke]);

        // Animate text much faster by chunking characters based on text length
        // We want it to finish in roughly 800ms
        final totalFrames = 800 ~/ 16; // approx 50 frames
        final charsPerStep = (fullText.length / totalFrames).ceil().clamp(
          1,
          20,
        );

        for (int i = 1; i <= fullText.length; i += charsPerStep) {
          await Future.delayed(const Duration(milliseconds: 16));

          int endIndex = i + charsPerStep;
          if (endIndex > fullText.length) endIndex = fullText.length;

          _currentStroke = stroke.copyWith(
            text: fullText.substring(0, endIndex),
          );

          // Use activeStrokeNotifier instead of rebuilding the full state list.
          // This only repaints the active-stroke layer (ValueListenableBuilder)
          // instead of triggering CanvasWidget.build() + O(n) list copies.
          activeStrokeNotifier.value = _currentStroke;
        }
        // Commit the final text to state once (one state rebuild instead of 50)
        final committedStrokes = List<Stroke>.from(state.strokes);
        committedStrokes.last = stroke; // final version with full text
        state = state.copyWith(strokes: committedStrokes);
        activeStrokeNotifier.value = null;
      } else {
        // Instant appearance for LaTeX, or Smooth Line drawing for geometric shapes
        if (stroke.toolType == ToolType.latex) {
          state = state.copyWith(strokes: [...state.strokes, stroke]);
          // Wait longer so it feels like they are deliberately solving and writing equations
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }

        // Chemistry strokes — animate the reveal via animationProgress
        // (ChemistryRevealWidget uses it as a clipRect widthFactor)
        if (stroke.smiles != null) {
          state = state.copyWith(
            strokes: [
              ...state.strokes,
              stroke.copyWith(animationProgress: 0.0),
            ],
          );
          const int frames = 60; // 1s reveal
          for (int f = 1; f <= frames; f++) {
            await Future.delayed(const Duration(milliseconds: 16));
            final double t = f / frames;
            final double eased = t < 0.5
                ? 2 * t * t
                : 1 - math.pow(-2 * t + 2, 2).toDouble() / 2;
            // Update via state (chemistry widget listens to stroke.animationProgress)
            // but batch every 4 frames to reduce rebuild frequency
            if (f % 4 == 0 || f == frames) {
              final updatedStrokes = List<Stroke>.from(state.strokes);
              if (updatedStrokes.isNotEmpty) {
                updatedStrokes.last = stroke.copyWith(animationProgress: eased);
                state = state.copyWith(strokes: updatedStrokes);
              }
            }
          }
          final finalStrokes = List<Stroke>.from(state.strokes);
          if (finalStrokes.isNotEmpty) {
            finalStrokes.last = stroke.copyWith(animationProgress: 1.0);
            state = state.copyWith(strokes: finalStrokes);
          }
          continue;
        }

        if (stroke.imageBytes != null) {
          state = state.copyWith(
            strokes: [
              ...state.strokes,
              stroke.copyWith(animationProgress: 0.0),
            ],
          );

          final int frames = 90; // 1.5s at 60fps
          for (int f = 1; f <= frames; f++) {
            await Future.delayed(const Duration(milliseconds: 16));
            final double progress = f / frames;
            // Ease in out quad
            final double eased = progress < 0.5
                ? 2 * progress * progress
                : 1 - math.pow(-2 * progress + 2, 2).toDouble() / 2;

            _currentStroke = stroke.copyWith(animationProgress: eased);
            // Use activeStrokeNotifier for mid-animation frames to avoid
            // full state rebuilds. Image progress is painted by DrawingCanvasPainter
            // via the active stroke layer.
            activeStrokeNotifier.value = _currentStroke;
          }

          activeStrokeNotifier.value = null;
          // Commit final stroke to state once
          final finalStrokes = List<Stroke>.from(state.strokes);
          // Replace the initial 0.0 progress placeholder with the final stroke
          if (finalStrokes.isNotEmpty) {
            finalStrokes.last = stroke.copyWith(animationProgress: 1.0);
          }
          state = state.copyWith(strokes: finalStrokes);

          continue;
        }

        _currentStroke = stroke.copyWith(points: [stroke.points.first]);

        state = state.copyWith(strokes: [...state.strokes, _currentStroke!]);

        // Interpolate points for smooth drawing animation — always densify
        // unless the stroke already has many points (e.g. SVG paths extracted at 4px steps)
        List<Offset> densePoints = [];
        if (stroke.points.length > 1 && stroke.points.length < 500) {
          for (int i = 0; i < stroke.points.length - 1; i++) {
            final p1 = stroke.points[i];
            final p2 = stroke.points[i + 1];
            final distance = (p2 - p1).distance;
            // Add a point every ~2 pixels for smooth animation
            final numSteps = (distance / 2.0).ceil().clamp(1, 2000);
            for (int step = 0; step < numSteps; step++) {
              densePoints.add(Offset.lerp(p1, p2, step / numSteps)!);
            }
          }
          densePoints.add(stroke.points.last);
        } else {
          densePoints = stroke.points;
        }

        final totalPoints = densePoints.length;

        if (totalPoints > 1) {
          // Use a Future.delayed loop at ~60fps — Ticker can't be used in a
          // Notifier (no vsync/TickerProvider available outside widgets).
          final ptsPerFrame = (totalPoints / 120.0).ceil().clamp(1, 15);
          int currentIndex = 1;

          // Remove the placeholder from state.strokes — the animation plays
          // through activeStrokeNotifier only, so we don't rebuild the full
          // widget tree on every frame. State is only updated once at the end.
          final withoutPlaceholder = List<Stroke>.from(state.strokes);
          if (withoutPlaceholder.isNotEmpty) withoutPlaceholder.removeLast();
          state = state.copyWith(strokes: withoutPlaceholder);

          while (currentIndex < totalPoints) {
            await Future.delayed(const Duration(milliseconds: 16));

            currentIndex = (currentIndex + ptsPerFrame).clamp(0, totalPoints);

            _currentStroke = stroke.copyWith(
              points: densePoints.sublist(0, currentIndex),
            );

            // Only update the lightweight ValueNotifier — no full state rebuild
            activeStrokeNotifier.value = _currentStroke;
          }

          activeStrokeNotifier.value = null;
          // Commit the final stroke to state once
          state = state.copyWith(strokes: [...state.strokes, stroke]);
        }
      }

      _currentStroke = null;
    }

    // Clean up temporary animation strokes and commit formally
    // This guarantees they enter the UndoHistory and SpatialIndex!
    final updatedStrokes = List<Stroke>.from(state.strokes);
    updatedStrokes.removeWhere((s) => newStrokes.any((ns) => ns.id == s.id));
    state = state.copyWith(strokes: updatedStrokes);

    _commitCommand(AddStrokesCommand(newStrokes));
  }

  void setTool(ToolType tool) {
    if (tool != ToolType.select && tool != ToolType.text) {
      clearSelection();
    }
    state = state.copyWith(currentTool: tool);
  }

  // ValueNotifier used to signal canvas_screen to show a text input dialog.
  // canvas_widget calls requestTextAt(pos) → canvas_screen listens and shows dialog.
  final ValueNotifier<Map<String, dynamic>?> textInsertRequest = ValueNotifier(
    null,
  );

  void requestTextAt(Offset canvasPosition, {Stroke? existingStroke}) {
    textInsertRequest.value = {
      'position': canvasPosition,
      'stroke': existingStroke,
    };
  }

  void deleteStroke(String id) {
    _isWarningDismissed = false;
    state = state.copyWith(
      strokes: state.strokes.where((s) => s.id != id).toList(),
    );
    _updateSimulationAndAi();
  }

  void setColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  void setSize(double size) {
    state = state.copyWith(currentSize: size);
  }

  void setLastAddedBounds(Rect? bounds) {
    state = state.copyWith(lastAddedBounds: bounds);
  }

  void setCanvasBackgroundColor(Color color) {
    state = state.copyWith(canvasBackgroundColor: color);
  }

  void setAiStatus(String? status, {Offset? target}) {
    if (status == null) {
      state = state.copyWith(clearAiStatus: true);
    } else {
      state = state.copyWith(aiStatus: status, aiStatusTarget: target);
    }
  }

  void dismissWarning() {
    _isWarningDismissed = true;
    state = state.copyWith(clearAiStatus: true);
  }

  int updateStrokeById(String id, Stroke Function(Stroke) updater, {bool force = false}) {
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (s.id == id) {
        if (s.isLocked && !force) {
          final updated = updater(s);
          if (!updated.isLocked) {
             count++;
             return updated;
          }
          return s;
        }
        count++;
        return updater(s);
      }
      return s;
    }).toList();
    if (count > 0) {
      _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
      _updateSimulationAndAi();
    }
    return count;
  }

  int updateStrokesByGroupId(String groupId, Stroke Function(Stroke) updater) {
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (s.groupId == groupId) {
        count++;
        return updater(s);
      }
      return s;
    }).toList();
    if (count > 0) {
      _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    }
    return count;
  }

  int replaceStrokeById(String id, Stroke newStroke) {
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (s.id == id) {
        count++;
        return newStroke;
      }
      return s;
    }).toList();
    if (count > 0) {
      _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    }
    return count;
  }

  int removeStrokesByIds(List<String> targetIds) {
    final initialLength = state.strokes.length;
    final newStrokes = state.strokes.where((s) {
      if (s.isLocked) return true; // Don't delete locked strokes
      return !targetIds.contains(s.id) &&
          !targetIds.contains(s.groupId) &&
          !targetIds.contains(s.name);
    }).toList();
    final count = initialLength - newStrokes.length;
    if (count > 0) {
      _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    }
    return count;
  }

  void eraseRect(Rect bounds) {
    final newStrokes = state.strokes.where((stroke) {
      if (stroke.isLocked) return true; // Don't erase locked strokes
      if (!stroke.bounds.overlaps(bounds)) {
        return true;
      }

      // Fine-grained pixel intersection check
      if (stroke.text != null || stroke.decodedImage != null) {
        return false; // If text/image bounds overlap, just delete it
      }

      for (final sp in stroke.points) {
        if (bounds.contains(sp)) {
          return false;
        }
      }

      return true; // Bounding box overlaps, but no points are inside
    }).toList();

    if (newStrokes.length != state.strokes.length) {
      _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    }
  }

  int tagStrokes(List<String> ids, String tag) {
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (ids.contains(s.id)) {
        count++;
        return s.copyWith(groupId: tag, name: tag);
      }
      return s;
    }).toList();
    if (count > 0) {
      _commitCommand(SnapshotCommand(List.from(state.strokes), newStrokes));
    }
    return count;
  }

  List<Stroke> _executeWidgetErasureAndGetStrokes() {
    if (_currentStroke == null || state.strokes.isEmpty) return state.strokes;

    double eMinX = double.infinity, eMinY = double.infinity;
    double eMaxX = double.negativeInfinity, eMaxY = double.negativeInfinity;
    for (var p in _currentStroke!.points) {
      if (p.dx < eMinX) eMinX = p.dx;
      if (p.dy < eMinY) eMinY = p.dy;
      if (p.dx > eMaxX) eMaxX = p.dx;
      if (p.dy > eMaxY) eMaxY = p.dy;
    }

    final eraserRadius = _currentStroke!.size;
    final eraserBounds = Rect.fromLTRB(
      eMinX - eraserRadius,
      eMinY - eraserRadius,
      eMaxX + eraserRadius,
      eMaxY + eraserRadius,
    );

    final newStrokes = state.strokes.where((stroke) {
      if (!stroke.bounds.overlaps(eraserBounds)) {
        return true;
      }

      // For widgets and latex, bounds overlap is enough to delete (since they are drawn as separate Flutter widgets outside the canvas layer)
      if (stroke.toolType == ToolType.latex ||
          stroke.toolType == ToolType.widget ||
          stroke.smiles != null) {
        return false;
      }

      return true;
    }).toList();

    return newStrokes;
  }

  void _updateSimulationAndAi() {
    Future.microtask(() {
      var newStrokes = TeslaEngine.updateWires(state.strokes);

      String? newAiStatus;
      Offset? newAiStatusTarget;
      bool shouldClearAiStatus = false;
      EasterEggEffect? surpriseEffect;
      String? surpriseMessage;

      if (state.canvasEnvironment == CanvasEnvironment.electronics) {
        // --- 1. Automatic Cleanup of unwanted text annotations ---
        final List<String> unwantedKeywords = [
          'circuit path',
          'corrected path',
          'circuit complete',
          'circuit path corrected',
          'circuit path completed',
          'connected the',
          'should now light up',
          'polarity guide',
        ];
        final List<String> unwantedExactLabels = [
          'battery',
          'switch',
          'resistor',
          'led',
          'ground',
          'vcc',
          'gnd',
          'capacitor',
          'inductor',
          'oscilloscope',
          'clock',
          'motor',
          'light',
        ];

        newStrokes = newStrokes.where((s) {
          if (s.toolType == ToolType.text && s.text != null) {
            final t = s.text!.trim().toLowerCase();
            if (unwantedExactLabels.contains(t)) return false;
            for (var kw in unwantedKeywords) {
              if (t.contains(kw)) return false;
            }
          }
          return true;
        }).toList();

        final debugger = CircuitDebuggerAi();
        final activeComponents = newStrokes
            .map((s) => ComponentRegistry().createComponent(s))
            .whereType<CircuitComponent>()
            .toList();

        final faults = debugger.analyzeCircuit(activeComponents);
        if (faults.isNotEmpty && !_isWarningDismissed) {
          final target = activeComponents.isNotEmpty
              ? activeComponents.first.originalStroke.bounds.topCenter -
                    const Offset(0, 40)
              : const Offset(0, 0);
          newAiStatus = faults.first;
          newAiStatusTarget = target;
        } else {
          shouldClearAiStatus = true;
        }

        final boolSolver = BooleanAlgebraSolver();
        for (var comp in activeComponents) {
          if (comp.type == 'and' || comp.type == 'or' || comp.type == 'not') {
            final equation = boolSolver.extractEquation(comp, activeComponents);
            final index = newStrokes.indexWhere(
              (s) => s.id == comp.originalStroke.id,
            );
            if (index != -1) {
              newStrokes[index] = newStrokes[index].copyWith(
                customMetadata: {
                  ...(newStrokes[index].customMetadata ?? {}),
                  'boolean_eq': equation,
                },
              );
            }
          }
        }

        // --- 2. Check for Completion Surprises ---
        final evaluatedComponents = TeslaEngine().activeComponents.values
            .toList();

        // Clean up tracking set for components no longer on canvas
        final currentCompIds = evaluatedComponents.map((c) => c.id).toSet();
        _completedComponentIds.removeWhere(
          (id) =>
              id != 'general_circuit_complete' && !currentCompIds.contains(id),
        );

        for (var comp in evaluatedComponents) {
          if (_completedComponentIds.contains(comp.id)) continue;

          bool isNewlyActive = false;
          if (comp.type.toLowerCase() == 'led' && comp.isActive) {
            isNewlyActive = true;
            surpriseEffect = EasterEggEffect.love;
            surpriseMessage =
                "💡 Brighter than the sun! LED circuit successfully illuminated! 🌟";
          } else if (comp.type.toLowerCase() == 'motor' && comp.isActive) {
            isNewlyActive = true;
            surpriseEffect = EasterEggEffect.snow;
            surpriseMessage =
                "🌀 Whoosh! The motor is spinning like a hurricane! 🌬️";
          } else if ((comp.type.toLowerCase().contains('gate') ||
                  comp.type.toLowerCase() == 'and' ||
                  comp.type.toLowerCase() == 'or' ||
                  comp.type.toLowerCase() == 'not') &&
              comp.isActive) {
            isNewlyActive = true;
            surpriseEffect = EasterEggEffect.done;
            surpriseMessage =
                "⚡ Logic Master! The logic gates have computed successfully! 🎉";
          }

          if (isNewlyActive) {
            _completedComponentIds.add(comp.id);
            break; // only trigger one surprise at a time
          }
        }

        // If no specific component was newly activated, check for general loop complete
        if (surpriseEffect == null) {
          bool hasBattery = evaluatedComponents.any(
            (c) =>
                c.type.toLowerCase() == 'battery' ||
                c.type.toLowerCase() == 'vcc',
          );
          bool hasGround = evaluatedComponents.any(
            (c) =>
                c.type.toLowerCase() == 'ground' ||
                c.type.toLowerCase() == 'gnd',
          );

          if (hasBattery &&
              hasGround &&
              faults.isEmpty &&
              evaluatedComponents.length >= 3) {
            final circuitKey = "general_circuit_complete";
            if (!_completedComponentIds.contains(circuitKey)) {
              _completedComponentIds.add(circuitKey);
              surpriseEffect = EasterEggEffect.fire;
              surpriseMessage =
                  "🔌 Power flows! The circuit is complete and fully functional! ⚡";
            }
          } else if (!hasBattery || !hasGround || faults.isNotEmpty) {
            _completedComponentIds.remove("general_circuit_complete");
          }
        }

        if (surpriseEffect != null) {
          try {
            ref
                .read(gamificationProvider.notifier)
                .unlockAchievement(surpriseEffect.name);
          } catch (e) {
            debugPrint("Failed to unlock achievement: $e");
          }
        }
      } else {
        shouldClearAiStatus = true;
      }

      state = state.copyWith(
        strokes: newStrokes,
        aiStatus: newAiStatus,
        aiStatusTarget: newAiStatusTarget,
        clearAiStatus: shouldClearAiStatus,
        activeEffect: surpriseEffect,
        effectTriggerTime: surpriseEffect != null ? DateTime.now() : null,
        activeEffectMessage: surpriseMessage,
      );

      _spatialIndex.buildIndex(state.strokes);
    });
  }
}

final drawingProvider = NotifierProvider<DrawingNotifier, DrawingState>(
  DrawingNotifier.new,
);
