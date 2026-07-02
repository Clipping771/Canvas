import 'task_scheduler.dart';

class WorldSimulation implements CognitiveSubsystem {
  @override
  TaskPriority get priority => TaskPriority.realtime; // Runs at 60fps to simulate particles/physics

  @override
  bool get isActive => true;

  @override
  void onTick(Duration elapsed) {
    // Step the physics engine, update particle systems, etc.
  }
}
