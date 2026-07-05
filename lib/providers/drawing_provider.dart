import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../models/tool_type.dart';
import '../engine/logic/tesla_engine.dart';
import '../engine/logic/components/component_registry.dart';
import '../models/easter_egg_mode.dart';
import '../models/canvas_environment.dart';
import '../engine/particle_engine.dart';
import '../engine/shape_recognizer.dart';
import '../engine/sound_engine.dart';
import 'gamification_provider.dart';

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
  final List<List<Stroke>> undoHistory;
  final List<List<Stroke>> redoHistory;
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
    
    
    this.canvasBackgroundColor = Colors.white,
    this.aiStatus,
    this.aiStatusTarget,
    this.showGoldenRatio = false,
  });

  DrawingState copyWith({
    List<Stroke>? strokes,
    List<List<Stroke>>? undoHistory,
    List<List<Stroke>>? redoHistory,
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
      canvasBackgroundColor:
          canvasBackgroundColor ?? this.canvasBackgroundColor,
      aiStatus: clearAiStatus ? null : (aiStatus ?? this.aiStatus),
      aiStatusTarget: clearAiStatus ? null : (aiStatusTarget ?? this.aiStatusTarget),
      showGoldenRatio: showGoldenRatio ?? this.showGoldenRatio,
    );
  }
}

class DrawingNotifier extends Notifier<DrawingState> {
  @override
  DrawingState build() {
    return DrawingState();
  }

  static List<Stroke> clipboard = [];
  Stroke? _currentStroke;
  Timer? _physicsTimer;

  void _startPhysicsLoop() {
    if (_physicsTimer?.isActive ?? false) return;
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      bool hasActivePhysics = false;
      final newStrokes = state.strokes.map<Stroke>((stroke) {
        if (stroke.physicsEnabled) {
          hasActivePhysics = true;
          // Apply gravity (simple constant downward force)
          final vY = (stroke.velocity?.dy ?? 0.0) + 0.5; // Gravity acceleration
          final vX = stroke.velocity?.dx ?? 0.0;
          
          // Move all points
          final newPoints = stroke.points.map((p) => Offset(p.dx + vX, p.dy + vY)).toList();
          
          // Simple floor collision (stop at Y=1500 for now, or bounce)
          bool hitFloor = false;
          for (var p in newPoints) {
            if (p.dy > 1500) hitFloor = true;
          }
          
          if (hitFloor) {
            return stroke.copyWith(
              points: newPoints.map((p) => Offset(p.dx, 1500 - (p.dy - 1500).abs())).toList(),
              velocity: Offset(vX * 0.8, -vY * 0.5), // Bounce and friction
            );
          }
          
          return stroke.copyWith(
            points: newPoints,
            velocity: Offset(vX, vY),
          );
        }
        return stroke;
      }).toList();

      if (hasActivePhysics) {
        state = state.copyWith(strokes: newStrokes);
      } else {
        _physicsTimer?.cancel();
      }
    });
  }

  void toggleGoldenRatio() {
    state = state.copyWith(showGoldenRatio: !state.showGoldenRatio);
  }

  /// Enable physics on all strokes belonging to [groupId] and start simulation.
  void applyGravityToGroup(String groupId) {
    _pushUndo();
    final newStrokes = state.strokes.map((s) {
      if (s.groupId == groupId || s.id == groupId || s.name == groupId) {
        return s.copyWith(physicsEnabled: true, velocity: Offset.zero);
      }
      return s;
    }).toList();
    state = state.copyWith(strokes: newStrokes);
    _startPhysicsLoop();
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
    List<Stroke> selected = [];
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var stroke in state.strokes) {
      bool intersects = false;

      if (stroke.decodedImage != null && stroke.points.isNotEmpty) {
        final imgRect = Rect.fromLTWH(
          stroke.points.first.dx,
          stroke.points.first.dy,
          stroke.decodedImage!.width.toDouble(),
          stroke.decodedImage!.height.toDouble(),
        );
        if (rect.overlaps(imgRect) || rect.contains(stroke.points.first)) {
          intersects = true;
        }
      } else if (stroke.text != null && stroke.points.isNotEmpty) {
        final lines = stroke.text!.split('\n');
        final maxLineLength = lines
            .map((l) => l.length)
            .reduce((a, b) => a > b ? a : b);
        final width = stroke.size * maxLineLength * 0.7;
        final height = stroke.size * 1.5 * lines.length;
        final textRect = Rect.fromLTWH(
          stroke.points.first.dx,
          stroke.points.first.dy,
          width,
          height,
        ).inflate(15);
        if (rect.overlaps(textRect) || rect.contains(stroke.points.first)) {
          intersects = true;
        }
      } else {
        for (var p in stroke.points) {
          if (rect.contains(p)) {
            intersects = true;
            break;
          }
        }
      }

      if (intersects) {
        selected.add(stroke);
        final bounds = stroke.bounds;
        if (bounds.left < minX) minX = bounds.left;
        if (bounds.top < minY) minY = bounds.top;
        if (bounds.right > maxX) maxX = bounds.right;
        if (bounds.bottom > maxY) maxY = bounds.bottom;
      }
    }

    if (selected.isNotEmpty) {
      state = state.copyWith(
        selectedStrokes: selected,
        selectionBounds: Rect.fromLTRB(minX, minY, maxX, maxY),
      );
    } else {
      clearSelection();
    }
  }

  void clearSelection() {
    if (state.selectedStrokes.isNotEmpty || state.selectionBounds != null) {
      state = state.copyWith(clearSelection: true, clearPreview: true);
    }
  }

  void setEasterEggMode(EasterEggMode mode) {
    state = state.copyWith(easterEggMode: mode, clearEasterEgg: true);
  }

  void clearEasterEgg() {
    state = state.copyWith(clearEasterEgg: true);
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
    final remaining = state.strokes
        .where((s) => !state.selectedStrokes.contains(s))
        .toList();
        
    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);
      
    state = state.copyWith(
      strokes: remaining,
      undoHistory: newUndoHistory,
      clearSelection: true,
      clearPreview: true,
    );
  }

  void copySelection() {
    if (state.selectedStrokes.isEmpty) return;
    
    // Push text to OS clipboard so it can be pasted outside the app
    final textStrokes = state.selectedStrokes.where((s) => s.text != null && s.text!.isNotEmpty).toList();
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
    
    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);
      
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
      undoHistory: newUndoHistory,
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

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

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
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  void startStroke(Offset position) {
    // Save state BEFORE starting a new stroke for Undo purposes
    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    state = state.copyWith(
      undoHistory: newUndoHistory,
      redoHistory: [], // Clear redo history on new stroke
    );

    _currentStroke = Stroke(
      points: [position],
      color: state.currentTool == ToolType.eraser
          ? Colors.transparent
          : state.currentColor,
      size: state.currentTool == ToolType.wire ? 4.0 : state.currentSize,
      toolType: state.currentTool,
      isFilled: state.currentTool == ToolType.fill,
    );
    state = state.copyWith(strokes: [...state.strokes, _currentStroke!]);

    SoundEngine.instance.startDrawing();
  }

  void updateStroke(Offset position) {
    if (_currentStroke == null) return;

    // Create a new list of points for the current stroke
    final updatedPoints = List<Offset>.from(_currentStroke!.points)
      ..add(position);

    // Create an updated stroke
    final updatedStroke = Stroke(
      points: updatedPoints,
      color: _currentStroke!.color,
      size: _currentStroke!.size,
      toolType: _currentStroke!.toolType,
      isFilled: _currentStroke!.isFilled,
    );

    _currentStroke = updatedStroke;

    // Calculate speed for sound engine
    final lastPoint = _currentStroke!.points[_currentStroke!.points.length - 2];
    final currentPoint = position;
    final dist = (currentPoint - lastPoint).distance;
    SoundEngine.instance.updateDrawingSpeed(dist);

    // Update the state with the new stroke replacing the old one
    final updatedStrokes = List<Stroke>.from(state.strokes);
    updatedStrokes[updatedStrokes.length - 1] = updatedStroke;

    state = state.copyWith(strokes: updatedStrokes);
  }

  void endStroke() {
    SoundEngine.instance.stopDrawing();

    if (_currentStroke != null && _currentStroke!.points.isNotEmpty) {
      if (state.currentTool == ToolType.fill &&
          _currentStroke!.points.length < 5) {
        // It was a tap! Execute bucket fill logic
        final tapPoint = _currentStroke!.points.first;
        // Remove the tiny dot stroke we just added during the tap
        final newStrokes = List<Stroke>.from(state.strokes)..removeLast();
        state = state.copyWith(strokes: newStrokes);

        _executeBucketFill(tapPoint);
        _currentStroke = null;
        return;
      }
      
      if (state.currentTool == ToolType.eraser) {
        // For a pixel eraser (like Photoshop), we MUST keep the eraser stroke itself
        // on the canvas so it can be rendered with BlendMode.clear.
        // We only delete intersecting widgets.
        _executeWidgetErasure();
        
        _currentStroke = null;
        return;
      }
      
      if (state.currentTool == ToolType.wire && _currentStroke!.points.length > 2) {
        final startPoint = _currentStroke!.points.first;
        final endPoint = _currentStroke!.points.last;

        Stroke? sourceStroke;
        Stroke? targetStroke;

        for (var s in state.strokes.take(state.strokes.length - 1)) {
          bool isSourceHit = false;
          bool isTargetHit = false;
          
          final comp = ComponentRegistry().createComponent(s);
          if (comp != null && comp.pins.isNotEmpty) {
            for (var pin in comp.pins) {
              final pinPos = s.bounds.center + pin.relativePosition;
              if ((pinPos - startPoint).distance < 40) isSourceHit = true;
              if ((pinPos - endPoint).distance < 40) isTargetHit = true;
            }
          }
          
          if (isSourceHit || s.bounds.inflate(40).contains(startPoint)) sourceStroke = s;
          if (isTargetHit || s.bounds.inflate(40).contains(endPoint)) targetStroke = s;
        }

        if (sourceStroke != null && targetStroke != null) {
          if (sourceStroke.toolType == ToolType.portal && targetStroke.toolType == ToolType.portal) {
            final newStrokes = List<Stroke>.from(state.strokes)..removeLast();
            
            Stroke copyStrokeWithMeta(Stroke s, String destinationId) {
              return Stroke(
                id: s.id, groupId: s.groupId, name: s.name, points: s.points,
                color: s.color, size: s.size, rotation: s.rotation, toolType: s.toolType,
                text: s.text, imageBytes: s.imageBytes, decodedImage: s.decodedImage,
                isFilled: s.isFilled, semanticMeaning: s.semanticMeaning, physicsEnabled: s.physicsEnabled,
                customMetadata: {...(s.customMetadata ?? {}), 'destinationId': destinationId},
                version: s.version + 1,
              );
            }
            
            final newSource = copyStrokeWithMeta(sourceStroke, targetStroke.id);
            final newTarget = copyStrokeWithMeta(targetStroke, sourceStroke.id);
            
            final sourceIndex = newStrokes.indexWhere((s) => s.id == sourceStroke!.id);
            if (sourceIndex != -1) newStrokes[sourceIndex] = newSource;
            
            final targetIndex = newStrokes.indexWhere((s) => s.id == targetStroke!.id);
            if (targetIndex != -1) newStrokes[targetIndex] = newTarget;

            state = state.copyWith(strokes: TeslaEngine.updateWires(newStrokes));
            _currentStroke = null;
            return;
          } else {
            final newMeta = {...(_currentStroke!.customMetadata ?? {})};
            newMeta['sourceId'] = sourceStroke.id;
            newMeta['targetId'] = targetStroke.id;
            
            // Resolve nearest Source Pin
            final sourceComp = ComponentRegistry().createComponent(sourceStroke);
            if (sourceComp != null && sourceComp.pins.isNotEmpty) {
              final center = sourceStroke.bounds.center;
              var minDistance = double.infinity;
              for (var pin in sourceComp.pins) {
                final pos = center + pin.relativePosition;
                final dist = (pos - startPoint).distance;
                if (dist < minDistance) {
                  minDistance = dist;
                  newMeta['sourcePinId'] = pin.id;
                }
              }
            }

            // Resolve nearest Target Pin
            final targetComp = ComponentRegistry().createComponent(targetStroke);
            if (targetComp != null && targetComp.pins.isNotEmpty) {
              final center = targetStroke.bounds.center;
              var minDistance = double.infinity;
              for (var pin in targetComp.pins) {
                final pos = center + pin.relativePosition;
                final dist = (pos - endPoint).distance;
                if (dist < minDistance) {
                  minDistance = dist;
                  newMeta['targetPinId'] = pin.id;
                }
              }
            }
            
            final correctedWire = Stroke(
                id: _currentStroke!.id, groupId: _currentStroke!.groupId, name: _currentStroke!.name, points: _currentStroke!.points,
                color: _currentStroke!.color, size: _currentStroke!.size, rotation: _currentStroke!.rotation, toolType: _currentStroke!.toolType,
                text: _currentStroke!.text, imageBytes: _currentStroke!.imageBytes, decodedImage: _currentStroke!.decodedImage,
                isFilled: _currentStroke!.isFilled, semanticMeaning: _currentStroke!.semanticMeaning, physicsEnabled: _currentStroke!.physicsEnabled,
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

      // Shape auto-correction: try to recognise circle / star / spiral
      final recognized = ShapeRecognizer.recognize(_currentStroke!.points);
      if (recognized != ShapeType.unknown) {
        final perfectPoints = ShapeRecognizer.generatePerfectShape(
          recognized,
          _currentStroke!.points,
        );
        if (perfectPoints.isNotEmpty) {
          final corrected = Stroke(
            points: perfectPoints,
            color: _currentStroke!.color,
            size: _currentStroke!.size,
            toolType: _currentStroke!.toolType,
            isFilled: _currentStroke!.isFilled,
          );
          // Replace the last stroke with the corrected one
          final correctedStrokes = List<Stroke>.from(state.strokes);
          correctedStrokes.last = corrected;
          state = state.copyWith(strokes: correctedStrokes);
          _currentStroke = corrected;
          // Award the achievement for the first successful correction
          ref.read(gamificationProvider.notifier).unlockAchievement('shape_master');
        }
      }

      if (maxX != double.negativeInfinity) {
        state = state.copyWith(lastAddedBounds: currentBounds);
      }
    }
    
    // Simulate circuit logic and recalculate wires
    state = state.copyWith(strokes: TeslaEngine.updateWires(state.strokes));
    _currentStroke = null;
  }

  void _executeBucketFill(Offset point) {
    // Search from top to bottom (reverse order) so we fill the front-most shape
    for (int i = state.strokes.length - 1; i >= 0; i--) {
      final stroke = state.strokes[i];
      if (stroke.points.isEmpty ||
          stroke.toolType == ToolType.latex ||
          stroke.toolType == ToolType.widget) {
        continue;
      }

      if (stroke.path.contains(point)) {
        final filledStroke = Stroke(
          points: stroke.points,
          color: state.currentColor,
          size: stroke.size,
          rotation: stroke.rotation,
          toolType: ToolType.pen,
          text: stroke.text,
          imageBytes: stroke.imageBytes,
          decodedImage: stroke.decodedImage,
          isFilled: true,
        );

        final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
          ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);
        final newStrokes = List<Stroke>.from(state.strokes);
        newStrokes.insert(i, filledStroke);

        state = state.copyWith(
          strokes: newStrokes,
          undoHistory: newUndoHistory,
          redoHistory: [],
        );
        return;
      }
    }
  }

  void undo() {
    if (state.undoHistory.isEmpty) return;

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory);
    final previousStrokes = newUndoHistory
        .removeLast(); // Get the state before the last stroke

    final newRedoHistory = List<List<Stroke>>.from(state.redoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes); // Save current state to redo

    state = state.copyWith(
      strokes: previousStrokes,
      undoHistory: newUndoHistory,
      redoHistory: newRedoHistory,
    );
  }

  void redo() {
    if (state.redoHistory.isEmpty) return;

    final newRedoHistory = List<List<Stroke>>.from(state.redoHistory);
    final nextStrokes = newRedoHistory.removeLast();

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    state = state.copyWith(
      strokes: nextStrokes,
      undoHistory: newUndoHistory,
      redoHistory: newRedoHistory,
    );
  }

  void clear() {
    if (state.strokes.isNotEmpty) {
      final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
        ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

      state = state.copyWith(
        strokes: [],
        undoHistory: newUndoHistory,
        redoHistory: [],
      );
    }
  }



  void eraseText(String textToErase) {
    if (state.strokes.isEmpty) return;

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    final lowercased = textToErase.toLowerCase();
    final newStrokes = state.strokes.where((stroke) {
      if (stroke.text != null) {
        return !stroke.text!.toLowerCase().contains(lowercased);
      }
      return true;
    }).toList();

    state = state.copyWith(
      strokes: newStrokes,
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  void eraseStrokes(List<Stroke> strokesToRemove) {
    if (strokesToRemove.isEmpty) return;

    // Save state BEFORE erasing for Undo purposes
    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    final newStrokes = List<Stroke>.from(state.strokes)
      ..removeWhere((s) => strokesToRemove.contains(s));

    state = state.copyWith(
      strokes: newStrokes,
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  void loadStrokes(List<Stroke> strokes) async {
    state = state.copyWith(strokes: strokes, undoHistory: [], redoHistory: []);
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

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

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
        undoHistory: newUndoHistory,
        redoHistory: [],
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
        undoHistory: newUndoHistory,
        redoHistory: [],
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

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    state = state.copyWith(
      strokes: [...state.strokes, ...newStrokes],
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  void moveLastStrokes(int count, Offset offset) {
    if (state.strokes.isEmpty || count <= 0) return;

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

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

    state = state.copyWith(
      strokes: newStrokes,
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  void transformStrokesInRect(
    Rect bounds, {
    double dx = 0,
    double dy = 0,
    double scale = 1.0,
    double rotation = 0.0,
  }) {
    if (state.strokes.isEmpty) return;

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);
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
      state = state.copyWith(
        strokes: newStrokes,
        undoHistory: newUndoHistory,
        redoHistory: [],
      );
    }
  }

  void removeStrokes(List<Stroke> strokesToRemove) {
    if (strokesToRemove.isEmpty) return;

    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
      ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

    final currentStrokes = List<Stroke>.from(state.strokes);
    currentStrokes.removeWhere((s) => strokesToRemove.contains(s));

    state = state.copyWith(
      strokes: currentStrokes,
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  Future<void> animateStrokes(List<Stroke> newStrokes) async {
    if (newStrokes.isEmpty) return;

    // Create a copy of the list and sort it from top to bottom (Y coordinate)
    // This ensures the animation feels like someone writing naturally down a page!
    final sortedStrokes = List<Stroke>.from(newStrokes);
    sortedStrokes.sort((a, b) {
      final aY = a.points.isNotEmpty ? a.points.first.dy : 0.0;
      final bY = b.points.isNotEmpty ? b.points.first.dy : 0.0;
      return aY.compareTo(bY);
    });

    for (var stroke in sortedStrokes) {
      if (stroke.points.isEmpty) continue;

      final newUndoHistory = List<List<Stroke>>.from(state.undoHistory)
        ..add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, state.redoHistory, state.strokes);

      if (stroke.text != null && stroke.toolType != ToolType.latex && stroke.toolType != ToolType.widget && stroke.smiles == null) {
        final fullText = stroke.text!;
        _checkEasterEggs(fullText);

        // If it's a short text/emoji, do a bouncy scale-in pop animation!
        if (fullText.length <= 3) {
          final targetSize = stroke.size;

          state = state.copyWith(
            strokes: [
              ...state.strokes,
              Stroke(
                points: stroke.points,
                color: stroke.color,
                size: 0.1,
                rotation: stroke.rotation,
                toolType: stroke.toolType,
                text: fullText,
              ),
            ],
            undoHistory: newUndoHistory,
            redoHistory: [],
          );

          final scales = [0.2, 0.5, 0.8, 1.2, 1.1, 0.95, 1.0];
          for (var s in scales) {
            await Future.delayed(const Duration(milliseconds: 30));
            _currentStroke = Stroke(
              points: stroke.points,
              color: stroke.color,
              size: targetSize * s,
              rotation: stroke.rotation,
              toolType: stroke.toolType,
              text: fullText,
            );

            final updatedStrokes = List<Stroke>.from(state.strokes);
            updatedStrokes.last = _currentStroke!;
            state = state.copyWith(strokes: updatedStrokes);
          }
        } else {
          // Typewriter animation for normal text
          final initialStroke = Stroke(
            points: stroke.points,
            color: stroke.color,
            size: stroke.size,
            toolType: stroke.toolType,
            text: "", // Start empty
          );
          state = state.copyWith(
            strokes: [...state.strokes, initialStroke],
            undoHistory: newUndoHistory,
            redoHistory: [],
          );

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

            _currentStroke = Stroke(
              points: stroke.points,
              color: stroke.color,
              size: stroke.size,
              toolType: stroke.toolType,
              text: fullText.substring(0, endIndex),
            );

            final updatedStrokes = List<Stroke>.from(state.strokes);
            updatedStrokes.last = _currentStroke!;
            state = state.copyWith(strokes: updatedStrokes);
          }
        }
      } else {
        // Instant appearance for LaTeX, or Smooth Line drawing for geometric shapes
        if (stroke.toolType == ToolType.latex) {
          state = state.copyWith(
            strokes: [...state.strokes, stroke],
            undoHistory: newUndoHistory,
            redoHistory: [],
          );
          // Wait longer so it feels like they are deliberately solving and writing equations
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }

        // Chemistry strokes — animate the reveal via animationProgress
        // (ChemistryRevealWidget uses it as a clipRect widthFactor)
        if (stroke.smiles != null) {
          state = state.copyWith(
            strokes: [...state.strokes, stroke.copyWith(animationProgress: 0.0)],
            undoHistory: newUndoHistory,
            redoHistory: [],
          );
          const int frames = 60; // 1s reveal
          for (int f = 1; f <= frames; f++) {
            await Future.delayed(const Duration(milliseconds: 16));
            final double t = f / frames;
            final double eased = t < 0.5
                ? 2 * t * t
                : 1 - math.pow(-2 * t + 2, 2).toDouble() / 2;
            final updatedStrokes = List<Stroke>.from(state.strokes);
            if (updatedStrokes.isNotEmpty) {
              updatedStrokes.last = stroke.copyWith(animationProgress: eased);
              state = state.copyWith(strokes: updatedStrokes);
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
            undoHistory: newUndoHistory,
            redoHistory: [],
          );
          
          final int frames = 90; // 1.5s at 60fps
          for (int f = 1; f <= frames; f++) {
            await Future.delayed(const Duration(milliseconds: 16));
            final double progress = f / frames;
            // Ease in out quad
            final double eased = progress < 0.5 ? 2 * progress * progress : 1 - math.pow(-2 * progress + 2, 2).toDouble() / 2;
            
            _currentStroke = stroke.copyWith(animationProgress: eased);
            
            final updatedStrokes = List<Stroke>.from(state.strokes);
            updatedStrokes.last = _currentStroke!;
            state = state.copyWith(strokes: updatedStrokes);
          }
          
          final finalStrokes = List<Stroke>.from(state.strokes);
          finalStrokes.last = stroke.copyWith(animationProgress: 1.0);
          state = state.copyWith(strokes: finalStrokes);
          
          continue;
        }

        _currentStroke = stroke.copyWith(
          points: [stroke.points.first],
        );

        state = state.copyWith(
          strokes: [...state.strokes, _currentStroke!],
          undoHistory: newUndoHistory,
          redoHistory: [],
        );

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

          while (currentIndex < totalPoints) {
            await Future.delayed(const Duration(milliseconds: 16));

            currentIndex = (currentIndex + ptsPerFrame).clamp(0, totalPoints);

            _currentStroke = stroke.copyWith(
              points: densePoints.sublist(0, currentIndex),
            );

            final updatedStrokes = List<Stroke>.from(state.strokes);
            if (updatedStrokes.isNotEmpty) {
              updatedStrokes.last = _currentStroke!;
              state = state.copyWith(strokes: updatedStrokes);
            }
          }

          // Replace final animated stroke with the original to preserve all metadata
          final finalStrokes = List<Stroke>.from(state.strokes);
          if (finalStrokes.isNotEmpty) {
            finalStrokes.last = stroke;
            state = state.copyWith(strokes: finalStrokes);
          }
        }
      }

      _currentStroke = null;
    }
  }

  void setTool(ToolType tool) {
    if (tool != ToolType.select && tool != ToolType.text) {
      clearSelection();
    }
    state = state.copyWith(currentTool: tool);
  }

  // ValueNotifier used to signal canvas_screen to show a text input dialog.
  // canvas_widget calls requestTextAt(pos) → canvas_screen listens and shows dialog.
  final ValueNotifier<Map<String, dynamic>?> textInsertRequest = ValueNotifier(null);

  void requestTextAt(Offset canvasPosition, {Stroke? existingStroke}) {
    textInsertRequest.value = {
      'position': canvasPosition,
      'stroke': existingStroke,
    };
  }

  /// Called by canvas_screen after the user typed text in the dialog.
  void placeText(String text, Offset position) {
    if (text.trim().isEmpty) return;
    final stroke = Stroke(
      points: [position],
      color: state.currentColor,
      size: 24.0, // Fixed comfortable size for Text Tool
      toolType: ToolType.text,
      text: text,
    );
    addStrokes([stroke]);
  }

  void deleteStroke(String id) {
    state = state.copyWith(
      strokes: state.strokes.where((s) => s.id != id).toList()
    );
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

  void _enforceHistoryLimit(List<List<Stroke>> history, List<List<Stroke>> redoHistory, List<Stroke> currentStrokes) {
    while (history.length > 50) {
      final discarded = history.removeAt(0);
      for (final stroke in discarded) {
        if (stroke.decodedImage != null) {
          bool isReferenced = false;
          
          for (final s in currentStrokes) {
            if (s.decodedImage == stroke.decodedImage) {
              isReferenced = true;
              break;
            }
          }
          if (isReferenced) continue;
          
          for (final snapshot in history) {
            for (final s in snapshot) {
              if (s.decodedImage == stroke.decodedImage) {
                isReferenced = true;
                break;
              }
            }
            if (isReferenced) break;
          }
          if (isReferenced) continue;
          
          for (final snapshot in redoHistory) {
            for (final s in snapshot) {
              if (s.decodedImage == stroke.decodedImage) {
                isReferenced = true;
                break;
              }
            }
            if (isReferenced) break;
          }
          if (isReferenced) continue;
          
          stroke.decodedImage!.dispose();
        }
      }
    }
  }

  void _pushUndo() {
    final newUndoHistory = List<List<Stroke>>.from(state.undoHistory);
    newUndoHistory.add(List.from(state.strokes));
    _enforceHistoryLimit(newUndoHistory, [], state.strokes);
    if (newUndoHistory.length > 50) newUndoHistory.removeAt(0);
    state = state.copyWith(undoHistory: newUndoHistory, redoHistory: []);
  }

  int updateStrokeById(String id, Stroke Function(Stroke) updater) {
    _pushUndo();
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (s.id == id) {
        count++;
        return updater(s);
      }
      return s;
    }).toList();
    if (count > 0) state = state.copyWith(strokes: newStrokes);
    return count;
  }

  int updateStrokesByGroupId(String groupId, Stroke Function(Stroke) updater) {
    _pushUndo();
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (s.groupId == groupId) {
        count++;
        return updater(s);
      }
      return s;
    }).toList();
    if (count > 0) state = state.copyWith(strokes: newStrokes);
    return count;
  }

  int replaceStrokeById(String id, Stroke newStroke) {
    _pushUndo();
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (s.id == id) {
        count++;
        return newStroke;
      }
      return s;
    }).toList();
    if (count > 0) state = state.copyWith(strokes: newStrokes);
    return count;
  }

  int removeStrokesByIds(List<String> targetIds) {
    _pushUndo();
    final initialLength = state.strokes.length;
    final newStrokes = state.strokes.where((s) {
      return !targetIds.contains(s.id) &&
          !targetIds.contains(s.groupId) &&
          !targetIds.contains(s.name);
    }).toList();
    final count = initialLength - newStrokes.length;
    if (count > 0) state = state.copyWith(strokes: newStrokes);
    return count;
  }

  void eraseRect(Rect bounds) {
    _pushUndo();
    final newStrokes = state.strokes.where((stroke) {
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
      state = state.copyWith(strokes: newStrokes);
    }
  }

  int tagStrokes(List<String> ids, String tag) {
    _pushUndo();
    int count = 0;
    final newStrokes = state.strokes.map((s) {
      if (ids.contains(s.id)) {
        count++;
        return s.copyWith(groupId: tag, name: tag);
      }
      return s;
    }).toList();
    if (count > 0) state = state.copyWith(strokes: newStrokes);
    return count;
  }

  void _executeWidgetErasure() {
    if (_currentStroke == null || state.strokes.isEmpty) return;
    
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
      eMaxY + eraserRadius
    );

    final eraserPoints = _currentStroke!.points;

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

    if (newStrokes.length != state.strokes.length) {
       state = state.copyWith(strokes: newStrokes);
    }
  }
}

final drawingProvider = NotifierProvider<DrawingNotifier, DrawingState>(
  DrawingNotifier.new,
);
