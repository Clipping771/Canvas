import 'dart:ui';
import 'package:vinci_board/engines/cognitive/task_scheduler.dart';
import 'package:vinci_board/engines/cognitive/spatial_memory.dart';

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
