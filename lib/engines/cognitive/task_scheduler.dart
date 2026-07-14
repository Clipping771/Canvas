import 'package:flutter/scheduler.dart';

enum TaskPriority {
  realtime, // Physics, UI Animations (60fps)
  high, // User interactions, Camera movement
  medium, // Avatar logic, World state updates
  low, // AI polling, prediction (event-driven or low frequency)
}

abstract class CognitiveSubsystem {
  void onTick(Duration elapsed);
  TaskPriority get priority;
  bool get isActive;
}

class TaskScheduler {
  static final TaskScheduler _instance = TaskScheduler._internal();
  factory TaskScheduler() => _instance;
  TaskScheduler._internal();

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  final List<CognitiveSubsystem> _subsystems = [];
  bool _isRunning = false;

  void registerSubsystem(CognitiveSubsystem subsystem) {
    if (!_subsystems.contains(subsystem)) {
      _subsystems.add(subsystem);
      _subsystems.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    }
  }

  void unregisterSubsystem(CognitiveSubsystem subsystem) {
    _subsystems.remove(subsystem);
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _ticker = Ticker(_onTick)..start();
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final delta = elapsed - _lastTick;
    _lastTick = elapsed;

    // Process highest priority first
    for (var subsystem in _subsystems) {
      if (subsystem.isActive) {
        // TODO: Add time-budgeting to prevent frame drops
        subsystem.onTick(delta);
      }
    }
  }
}
