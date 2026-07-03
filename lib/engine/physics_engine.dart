import 'package:flutter/scheduler.dart';
import 'dart:ui';
import '../models/stroke.dart';
import '../core/event_bus.dart';

class PhysicsState {
  Offset velocity;
  Offset acceleration;
  double angularVelocity;
  
  PhysicsState({
    this.velocity = Offset.zero,
    this.acceleration = Offset.zero,
    this.angularVelocity = 0.0,
  });
}

/// A self-contained, frame-based physics engine that uses
/// [SchedulerBinding.scheduleFrameCallback] — no vsync/Ticker needed.
class PhysicsEngine {
  static final PhysicsEngine _instance = PhysicsEngine._internal();
  factory PhysicsEngine() => _instance;
  
  final Map<String, PhysicsState> _objectStates = {};
  
  // Physics constants (canvas-coordinate units, ~60fps frames)
  final double gravityPerFrame = 2.5;   // pixels per frame² downward
  final double friction = 0.99;
  final double bounceFactor = 0.55;
  
  Function(List<Stroke> updatedStrokes)? onPhysicsUpdate;
  List<Stroke> _activeStrokes = [];
  bool _running = false;
  double _floorY = 1800.0; // default, updated by attachStrokes caller

  PhysicsEngine._internal() {
    EventBus().subscribe(EventType.physicsTriggered, _handlePhysicsEvent);
  }

  void _handlePhysicsEvent(CanvasEvent event) {
    final action = event.payload['action'];
    if (action == 'apply_gravity') {
      startSimulation();
    }
  }

  void attachStrokes(List<Stroke> strokes, {double floorY = 1800.0}) {
    _activeStrokes = strokes;
    _floorY = floorY;
    for (var stroke in strokes) {
      if (stroke.physicsEnabled && !_objectStates.containsKey(stroke.id)) {
        _objectStates[stroke.id] = PhysicsState(
          velocity: Offset.zero,
          acceleration: Offset(0, gravityPerFrame),
        );
      }
    }
  }

  void startSimulation() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }

  void stopSimulation() {
    _running = false;
    _objectStates.clear();
  }

  void _tick(Duration timestamp) {
    if (!_running) return;
    if (_activeStrokes.isEmpty || onPhysicsUpdate == null) {
      _running = false;
      return;
    }

    bool hasMoved = false;
    final List<Stroke> updatedStrokes = [];

    for (var stroke in _activeStrokes) {
      if (!stroke.physicsEnabled) {
        updatedStrokes.add(stroke);
        continue;
      }

      final pState = _objectStates[stroke.id];
      if (pState == null) {
        updatedStrokes.add(stroke);
        continue;
      }

      // Apply gravity
      pState.velocity += pState.acceleration;
      pState.velocity = Offset(
        pState.velocity.dx * friction,
        pState.velocity.dy, // gravity is lossless vertically
      );

      // Stop when nearly motionless
      if (pState.velocity.distance < 0.3 && pState.acceleration == Offset.zero) {
        updatedStrokes.add(stroke);
        continue;
      }

      hasMoved = true;
      final newPoints = stroke.points.map((p) => p + pState.velocity).toList();
      
      // Floor collision
      double maxY = newPoints.fold(0.0, (m, p) => p.dy > m ? p.dy : m);
      if (maxY >= _floorY) {
        final overshoot = maxY - _floorY;
        final correctedPoints = newPoints.map((p) => Offset(p.dx, p.dy - overshoot)).toList();
        pState.velocity = Offset(
          pState.velocity.dx * 0.6,
          -pState.velocity.dy.abs() * bounceFactor,
        );
        if (pState.velocity.dy.abs() < 1.0) {
          pState.velocity = Offset(pState.velocity.dx * 0.5, 0);
          pState.acceleration = Offset.zero; // resting
        }
        updatedStrokes.add(stroke.copyWith(points: correctedPoints));
      } else {
        updatedStrokes.add(stroke.copyWith(points: newPoints));
      }
    }

    if (hasMoved) {
      onPhysicsUpdate!(updatedStrokes);
      // Schedule next frame
      SchedulerBinding.instance.scheduleFrameCallback(_tick);
    } else {
      stopSimulation();
    }
  }
}
