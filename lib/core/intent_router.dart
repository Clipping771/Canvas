import 'dart:async';
import 'package:flutter/foundation.dart';
import 'event_bus.dart';

enum EnginePriority {
  high, // Blocks UI, runs first (e.g. Core Drawing, Quiz UI)
  medium, // Awaits High, then runs (e.g. AI Text Generation)
  low, // Runs Async, non-blocking (e.g. Physics, Particles)
}

class RoutedIntent {
  final String actionName;
  final Map<String, dynamic> payload;
  final EnginePriority priority;

  RoutedIntent({
    required this.actionName,
    required this.payload,
    required this.priority,
  });
}

class MultiIntentRouter {
  static final MultiIntentRouter _instance = MultiIntentRouter._internal();
  factory MultiIntentRouter() => _instance;
  MultiIntentRouter._internal();

  // UX Safety Layer State
  bool _isLearningActive = false;

  void setLearningState(bool active) {
    _isLearningActive = active;
  }

  /// Takes a raw list of AI ops and splits them by Engine Priority.
  Future<void> routeOps(List<dynamic> ops) async {
    final List<RoutedIntent> highPriority = [];
    final List<RoutedIntent> mediumPriority = [];
    final List<RoutedIntent> lowPriority = [];

    for (var op in ops) {
      if (op is Map<String, dynamic>) {
        final action = op['action'] as String?;
        if (action == null) continue;

        // UX Safety Rule: Block magic/chaos if learning is active
        if (_isLearningActive && _isMagicOrChaos(action)) {
          debugPrint("UX Safety: Blocked chaos action '$action' during active learning session.");
          continue;
        }

        // Route to engines based on action type
        if (_isPhysicsOrEnvironment(action)) {
          lowPriority.add(RoutedIntent(actionName: action, payload: op, priority: EnginePriority.low));
        } else if (_isLearningOrBlocking(action)) {
          highPriority.add(RoutedIntent(actionName: action, payload: op, priority: EnginePriority.high));
        } else {
          // Default to Drawing (Medium - we want it to draw synchronously, but after blocking quizzes)
          mediumPriority.add(RoutedIntent(actionName: action, payload: op, priority: EnginePriority.medium));
        }
      }
    }

    // 1. Execute High Priority (Blocking)
    for (var intent in highPriority) {
      await _executeIntent(intent);
    }

    // 2. Execute Medium Priority (Drawing)
    for (var intent in mediumPriority) {
      await _executeIntent(intent);
    }

    // 3. Execute Low Priority (Async - Physics/Environment)
    for (var intent in lowPriority) {
      // Fire and forget
      unawaited(_executeIntent(intent));
    }
  }

  bool _isMagicOrChaos(String action) {
    return ['trigger_chaos', 'black_hole', 'earthquake', 'glitch'].contains(action);
  }

  bool _isPhysicsOrEnvironment(String action) {
    return ['apply_gravity', 'tween_area', 'trigger_effect'].contains(action);
  }

  bool _isLearningOrBlocking(String action) {
    return ['trigger_quiz', 'ask_clarification'].contains(action);
  }

  Future<void> _executeIntent(RoutedIntent intent) async {
    try {
      if (intent.actionName == 'trigger_quiz') {
         EventBus().publish(EventType.aiActionDispatched, intent.payload);
      } else if (intent.priority == EnginePriority.low) {
         EventBus().publish(EventType.physicsTriggered, intent.payload);
      } else {
         EventBus().publish(EventType.canvasUpdated, intent.payload);
      }
    } catch (e) {
      EventBus().publish(EventType.systemError, {'error': e.toString(), 'action': intent.actionName});
      debugPrint("Engine Error: \$e");
    }
  }
}
