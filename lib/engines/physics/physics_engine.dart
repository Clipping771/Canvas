import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:ui';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/simulation_world.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/body.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/material.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/scenario.dart';
import 'package:vinci_board/engines/physics/physics_v2/core/collision_solver.dart';
import 'package:vinci_board/engines/physics/physics_v2/core/constraint_solver.dart';
import 'package:vinci_board/core/models/tool_type.dart';

/// A self-contained, frame-based physics engine that uses the Layer 2 SimulationWorld
class PhysicsEngine {
  static final PhysicsEngine _instance = PhysicsEngine._internal();
  factory PhysicsEngine() => _instance;

  final SimulationWorld _world = SimulationWorld();
  late final CollisionSolver _solver;

  Function(List<Stroke> updatedStrokes)? onPhysicsUpdate;
  List<Stroke> _activeStrokes = [];
  bool _running = false;
  Duration? _lastTimestamp;
  double _lastDt = 1.0 / 60.0;
  StreamSubscription<BaseEvent>? _eventSubscription;
  EventBus? _eventBus;

  PhysicsEngine._internal() {
    _solver = CollisionSolver(_world);
  }

  /// Subscribes this engine to the application event stream.
  /// Use the shared EventBus instance provided by [eventBusProvider] for
  /// application-wide event communication. Creating a new EventBus instance
  /// results in an independent event stream.
  /// This method is idempotent: repeated calls with the same [eventBus]
  /// instance are no-ops. A different instance cancels the prior subscription
  /// before resubscribing.
  void init(EventBus eventBus) {
    if (identical(_eventBus, eventBus) && _eventSubscription != null) return;
    _eventSubscription?.cancel();
    _eventBus = eventBus;
    _eventSubscription = eventBus.stream.listen((e) {
      if (e is GenericEvent && e.type == EventTypes.physicsTriggered) {
        _handlePhysicsEvent(e);
      }
    });
  }

  SimulationWorld get world => _world;
  PhysicsScenario get currentScenario => _world.currentScenario;
  void setScenario(PhysicsScenario scenario) {
    _world.setScenario(scenario);
  }

  void _handlePhysicsEvent(BaseEvent event) {
    final action = (event is GenericEvent ? event.payload : null)['action'];
    if (action == 'apply_gravity') {
      startSimulation();
    }
  }

  void attachStrokes(List<Stroke> strokes) {
    _activeStrokes = strokes;

    // Map strokes to physics bodies
    for (var stroke in strokes) {
      if (stroke.physicsEnabled && _world.getBody(stroke.id) == null) {
        // Calculate center of mass roughly (average of points)
        Offset center = Offset.zero;
        if (stroke.points.isNotEmpty) {
          for (var p in stroke.points) {
            center += p;
          }
          center /= stroke.points.length.toDouble();
        }

        final body = PhysicsBody(
          id: stroke.id,
          type: BodyType.dynamicBody,
          material: PhysicsMaterial.rubber,
          position: center,
        );
        _world.addBody(body);
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
    _lastTimestamp = null;
    _world.clear();
  }

  void _tick(Duration timestamp) {
    if (!_running) return;
    if (_activeStrokes.isEmpty || onPhysicsUpdate == null) {
      _running = false;
      return;
    }

    _lastTimestamp ??= timestamp;

    // Calculate real delta time in seconds, cap at 0.1s to prevent huge jumps if the app stalls
    double rawDt = (timestamp - _lastTimestamp!).inMicroseconds / 1000000.0;
    if (rawDt > 0.05) {
      rawDt = 0.05; // Cap at 50ms to prevent simulation explosion
    }
    if (rawDt <= 0) rawDt = 1.0 / 60.0; // fallback

    // Apply a simple low-pass filter to smooth out frame-time jitter
    _lastDt = (_lastDt * 0.8) + (rawDt * 0.2);
    double dt = _lastDt;

    _lastTimestamp = timestamp;

    // 1. Step the simulation
    _world.step(dt);

    // 2. Resolve collisions
    _solver.resolve();

    bool hasMoved = false;
    final List<Stroke> updatedStrokes = [];

    for (var stroke in _activeStrokes) {
      if (!stroke.physicsEnabled) {
        updatedStrokes.add(stroke);
        continue;
      }

      final body = _world.getBody(stroke.id);
      if (body == null) {
        updatedStrokes.add(stroke);
        continue;
      }

      // Check if body is moving
      if (body.velocity.distance > 0.1 || body.force != Offset.zero) {
        hasMoved = true;
      }

      // Map new body position back to stroke points
      // We calculate the delta from the body's previous position.
      final strokeDelta = body.position - body.previousPosition;

      if (strokeDelta != Offset.zero) {
        final newPoints = stroke.points.map((p) => p + strokeDelta).toList();
        updatedStrokes.add(stroke.copyWith(points: newPoints));
      } else {
        updatedStrokes.add(stroke);
      }
    }

    // Render constraints visually (e.g. Springs)
    for (var constraint in _world.constraints) {
      if (constraint is SpringConstraint) {
        final stroke = Stroke(
          id: 'spring_${constraint.bodyA.id}_${constraint.bodyB.id}',
          points: [constraint.bodyA.position, constraint.bodyB.position],
          color: const Color(0xFF9E9E9E), // Grey
          size: 4.0,
          toolType: ToolType.pen, // Render as a simple pen line for now
          groupId: 'physics_constraints',
        );
        updatedStrokes.add(stroke);
        hasMoved = true; // Always re-render while constraints exist
      }
    }

    if (hasMoved) {
      _activeStrokes = updatedStrokes;
      onPhysicsUpdate!(updatedStrokes);
      SchedulerBinding.instance.scheduleFrameCallback(_tick);
    } else {
      stopSimulation();
    }
  }
}
