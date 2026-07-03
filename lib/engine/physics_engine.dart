import 'dart:async';
import 'package:flutter/foundation.dart';
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

class PhysicsEngine {
  static final PhysicsEngine _instance = PhysicsEngine._internal();
  factory PhysicsEngine() => _instance;
  
  Ticker? _ticker;
  final Map<String, PhysicsState> _objectStates = {};
  
  // Custom lightweight physics properties
  final double gravity = 9.8;
  final double friction = 0.98;
  final double bounceFactor = -0.6;
  
  Function(List<Stroke> updatedStrokes)? onPhysicsUpdate;
  List<Stroke> _activeStrokes = [];

  PhysicsEngine._internal() {
    EventBus().subscribe(EventType.physicsTriggered, _handlePhysicsEvent);
  }

  void _handlePhysicsEvent(CanvasEvent event) {
    // If intent router sends a physics event (e.g. 'apply_gravity')
    final action = event.payload['action'];
    if (action == 'apply_gravity') {
      _startSimulation();
    }
  }

  void attachStrokes(List<Stroke> strokes) {
    _activeStrokes = strokes;
    for (var stroke in strokes) {
      if (stroke.physicsEnabled && !_objectStates.containsKey(stroke.id)) {
        _objectStates[stroke.id] = PhysicsState(
          acceleration: Offset(0, gravity),
        );
      }
    }
  }

  Duration _lastTickTime = Duration.zero;

  void _startSimulation() {
    if (_ticker == null || !_ticker!.isActive) {
      _lastTickTime = Duration.zero;
      _ticker = Ticker(_tick)..start();
    }
  }

  void stopSimulation() {
    _ticker?.stop();
  }

  void _tick(Duration elapsed) {
    if (_activeStrokes.isEmpty || onPhysicsUpdate == null) return;
    
    if (elapsed.inMilliseconds - _lastTickTime.inMilliseconds < 33) {
      return; // Throttle to ~30 FPS
    }
    _lastTickTime = elapsed;

    bool hasMoved = false;
    final List<Stroke> updatedStrokes = [];

    // Screen bounds for simple collision (Hardcoded 1080p for now, should be injected)
    const floorY = 1080.0;

    for (var stroke in _activeStrokes) {
      if (!stroke.physicsEnabled) {
        updatedStrokes.add(stroke);
        continue;
      }

      final state = _objectStates[stroke.id];
      if (state == null) continue;

      // Update velocity
      state.velocity += state.acceleration;
      state.velocity = Offset(
        state.velocity.dx * friction,
        state.velocity.dy * friction,
      );

      // Stop jitter
      if (state.velocity.distance < 0.1 && state.acceleration.dy == 0) {
        updatedStrokes.add(stroke);
        continue;
      }

      hasMoved = true;

      // Translate points
      final newPoints = stroke.points.map((p) => p + state.velocity).toList();
      
      // Simple floor collision bounds check
      double maxY = 0;
      for (var p in newPoints) {
        if (p.dy > maxY) maxY = p.dy;
      }

      if (maxY > floorY) {
        // Bounce
        state.velocity = Offset(state.velocity.dx, state.velocity.dy * bounceFactor);
        
        // Correct position to floor
        final diff = floorY - maxY;
        for (int i = 0; i < newPoints.length; i++) {
          newPoints[i] = Offset(newPoints[i].dx, newPoints[i].dy + diff);
        }
        
        if (state.velocity.dy.abs() < 1.0) {
          state.velocity = Offset(state.velocity.dx, 0);
          state.acceleration = Offset.zero; // Rest
        }
      }

      updatedStrokes.add(stroke.copyWith(points: newPoints));
    }

    if (hasMoved) {
      onPhysicsUpdate!(updatedStrokes);
    } else {
      stopSimulation();
    }
  }
}
