import 'dart:ui';
import 'task_scheduler.dart';
import '../../models/stroke.dart';

class MorphEngine implements CognitiveSubsystem {
  @override
  TaskPriority get priority => TaskPriority.high; // UI Animations

  @override
  bool get isActive => false; // Activated only when a morph is requested

  @override
  void onTick(Duration elapsed) {
    // Implement path interpolation between two semantic shapes
  }
}
