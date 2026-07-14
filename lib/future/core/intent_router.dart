// ignore_for_file: unused_field
import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';

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
  bool _isLearningActive = false;
  static final MultiIntentRouter _instance = MultiIntentRouter._internal();
  factory MultiIntentRouter() => _instance;
  MultiIntentRouter._internal();

  // UX Safety Layer State

  void setLearningState(bool active) {
    _isLearningActive = active;
  }

  /// Routes a list of AI ops to the appropriate engines by priority.
  /// [eventBus] must be the shared instance obtained from [eventBusProvider].
  /// Do not pass a bare `EventBus()` constructor — each construction produces
  /// an isolated stream that will never deliver events to other components.
  /// [isLearningActive] controls the UX safety filter for the duration of this
  /// call only. Pass `true` when a learning session is in progress to suppress
  /// chaos/magic actions. Defaults to `false` — the filter is off unless
  /// explicitly enabled per call, preventing stale state across sessions.
  Future<void> routeOps(
    List<dynamic> ops,
    EventBus eventBus, {
    bool isLearningActive = false,
  }) async {
    final List<RoutedIntent> highPriority = [];
    final List<RoutedIntent> mediumPriority = [];
    final List<RoutedIntent> lowPriority = [];

    for (var op in ops) {
      if (op is Map<String, dynamic>) {
        final action = op['action'] is String ? op['action'] as String : null;
        if (action == null) continue;

        // UX Safety Rule: Block magic/chaos if learning is active
        if (isLearningActive && _isMagicOrChaos(action)) {
          debugPrint(
            "UX Safety: Blocked chaos action '$action' during active learning session.",
          );
          continue;
        }

        // Route by table lookup; unknown actions default to medium with a diagnostic warning
        final priority = _actionPriorityTable[action] ?? EnginePriority.medium;
        if (!_actionPriorityTable.containsKey(action)) {
          log(
            'Unknown action "$action" defaulted to medium priority.',
            name: 'MultiIntentRouter',
          );
        }

        switch (priority) {
          case EnginePriority.high:
            highPriority.add(
              RoutedIntent(actionName: action, payload: op, priority: priority),
            );
          case EnginePriority.medium:
            mediumPriority.add(
              RoutedIntent(actionName: action, payload: op, priority: priority),
            );
          case EnginePriority.low:
            lowPriority.add(
              RoutedIntent(actionName: action, payload: op, priority: priority),
            );
        }
      }
    }

    // 1. Execute High Priority (Blocking)
    for (var intent in highPriority) {
      await _executeIntent(intent, eventBus);
    }

    // 2. Execute Medium Priority (Drawing)
    for (var intent in mediumPriority) {
      await _executeIntent(intent, eventBus);
    }

    // 3. Execute Low Priority (Async - Physics/Environment)
    for (var intent in lowPriority) {
      // Fire and forget
      unawaited(_executeIntent(intent, eventBus));
    }
  }

  /// Routing table mapping known action strings to their [EnginePriority].
  /// Actions not present in this table are silently routed to [EnginePriority.medium]
  /// and a diagnostic warning is emitted via [log].
  static const Map<String, EnginePriority> _actionPriorityTable = {
    // High priority — blocks UI
    'trigger_quiz': EnginePriority.high,
    'ask_clarification': EnginePriority.high,
    // Medium priority — drawing operations (default bucket)
    'draw_text': EnginePriority.medium,
    'draw_shape': EnginePriority.medium,
    'draw_svg': EnginePriority.medium,
    'draw_composite': EnginePriority.medium,
    'insert_uml': EnginePriority.medium,
    'insert_widget': EnginePriority.medium,
    'insert_chemistry': EnginePriority.medium,
    'generate_image': EnginePriority.medium,
    'update': EnginePriority.medium,
    'remove': EnginePriority.medium,
    'tag': EnginePriority.medium,
    'clear_canvas': EnginePriority.medium,
    'change_background': EnginePriority.medium,
    'undo': EnginePriority.medium,
    'delete_area': EnginePriority.medium,
    'erase_rect': EnginePriority.medium,
    'focus_area': EnginePriority.medium,
    'learn_rule': EnginePriority.medium,
    // Low priority — async, non-blocking
    'apply_gravity': EnginePriority.low,
    'apply_animation': EnginePriority.low,
    'stop_physics': EnginePriority.low,
    'stop_simulation': EnginePriority.low,
    'trigger_effect': EnginePriority.low,
    // Chaos/magic — low priority, suppressed during learning sessions
    'trigger_chaos': EnginePriority.low,
    'black_hole': EnginePriority.low,
    'earthquake': EnginePriority.low,
    'glitch': EnginePriority.low,
  };

  /// Returns true if [action] is a chaos/magic action that should be
  /// suppressed during active learning sessions.
  static const Set<String> _chaosActions = {
    'trigger_chaos',
    'black_hole',
    'earthquake',
    'glitch',
  };

  bool _isMagicOrChaos(String action) => _chaosActions.contains(action);

  Future<void> _executeIntent(RoutedIntent intent, EventBus eventBus) async {
    try {
      if (intent.actionName == 'trigger_quiz') {
        eventBus.publish(
          BaseEvent.generic('aiActionDispatched', payload: intent.payload),
        );
      } else if (intent.priority == EnginePriority.low) {
        eventBus.publish(
          BaseEvent.generic('physicsTriggered', payload: intent.payload),
        );
      } else {
        eventBus.publish(
          BaseEvent.generic('canvasUpdated', payload: intent.payload),
        );
      }
    } catch (e) {
      eventBus.publish(
        BaseEvent.generic(
          'systemError',
          payload: {'error': e.toString(), 'action': intent.actionName},
        ),
      );
      log('Engine Error: $e', name: 'MultiIntentRouter', error: e);
    }
  }
}
