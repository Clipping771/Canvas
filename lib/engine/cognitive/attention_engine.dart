import 'dart:ui';
import 'task_scheduler.dart';
import 'spatial_memory.dart';

class AttentionEngine implements CognitiveSubsystem {
  final SpatialMemory spatialMemory;
  
  Rect? currentFocusArea;
  double importanceScoreThreshold = 0.5;

  AttentionEngine(this.spatialMemory);

  @override
  TaskPriority get priority => TaskPriority.low; // Runs occasionally to determine AI focus

  @override
  bool get isActive => true;

  @override
  void onTick(Duration elapsed) {
    // Determine where the AI should look based on user cursor, recently added strokes, etc.
  }
}
