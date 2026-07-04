import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'task_scheduler.dart';
import 'spatial_memory.dart';

enum AvatarState {
  idle,
  thinking,
  observing,
  generating,
  helping,
  following,
  moving
}

class AvatarEngine implements CognitiveSubsystem {
  final SpatialMemory spatialMemory;

  final ValueNotifier<Offset> position = ValueNotifier(const Offset(100, 100));
  final ValueNotifier<AvatarState> state = ValueNotifier(AvatarState.idle);
  final ValueNotifier<String?> speechBubble = ValueNotifier(null);

  Offset _targetPosition = const Offset(100, 100);
  double _speed = 5.0; // pixels per frame

  AvatarEngine(this.spatialMemory);

  void moveTo(Offset target) {
    _targetPosition = target;
    state.value = AvatarState.moving;
  }

  void speak(String text) {
    speechBubble.value = text;
    Future.delayed(const Duration(seconds: 4), () {
      if (speechBubble.value == text) {
        speechBubble.value = null;
      }
    });
  }

  void setState(AvatarState newState) {
    state.value = newState;
  }

  @override
  TaskPriority get priority => TaskPriority.medium;

  @override
  bool get isActive => true;

  @override
  void onTick(Duration elapsed) {
    // Simple linear interpolation towards target
    if (position.value != _targetPosition) {
      double dx = _targetPosition.dx - position.value.dx;
      double dy = _targetPosition.dy - position.value.dy;
      double distSq = dx * dx + dy * dy;
      double dist = math.sqrt(distSq);

      if (dist < _speed) {
        position.value = _targetPosition;
        if (state.value == AvatarState.moving) {
          state.value = AvatarState.idle;
        }
      } else {
        position.value = Offset(
          position.value.dx + (dx / dist) * _speed,
          position.value.dy + (dy / dist) * _speed,
        );
      }
    }
  }
}
