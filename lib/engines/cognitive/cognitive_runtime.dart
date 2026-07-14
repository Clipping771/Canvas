import 'package:vinci_board/engines/cognitive/task_scheduler.dart';
import 'package:vinci_board/engines/cognitive/spatial_memory.dart';
import 'package:vinci_board/engines/cognitive/attention_engine.dart';
import 'package:vinci_board/engines/cognitive/avatar_engine.dart';
import 'package:vinci_board/engines/cognitive/prediction_engine.dart';
import 'package:vinci_board/engines/cognitive/physics_engine.dart';
import 'package:vinci_board/engines/cognitive/morph_engine.dart';
import 'package:vinci_board/engines/cognitive/timeline_engine.dart';
import 'package:vinci_board/engines/cognitive/script_runtime.dart';

class CognitiveRuntime {
  static final CognitiveRuntime _instance = CognitiveRuntime._internal();
  factory CognitiveRuntime() => _instance;

  late final TaskScheduler scheduler;
  late final SpatialMemory spatialMemory;
  late final AttentionEngine attentionEngine;
  late final AvatarEngine avatarEngine;
  late final PredictionEngine predictionEngine;
  late final CognitivePhysicsSubsystem physicsEngine;
  late final MorphEngine morphEngine;
  late final TimelineEngine timelineEngine;
  late final ScriptRuntime scriptRuntime;

  bool _initialized = false;

  CognitiveRuntime._internal() {
    scheduler = TaskScheduler();
    spatialMemory = SpatialMemory();
    attentionEngine = AttentionEngine(spatialMemory);
    avatarEngine = AvatarEngine(spatialMemory);
    predictionEngine = PredictionEngine(spatialMemory, attentionEngine);
    physicsEngine = CognitivePhysicsSubsystem();
    morphEngine = MorphEngine();
    timelineEngine = TimelineEngine();
    scriptRuntime = ScriptRuntime();
  }

  void initialize() {
    if (_initialized) return;

    // Register base subsystems
    scheduler.registerSubsystem(attentionEngine);
    scheduler.registerSubsystem(avatarEngine);
    scheduler.registerSubsystem(predictionEngine);
    scheduler.registerSubsystem(physicsEngine);
    scheduler.registerSubsystem(morphEngine);
    scheduler.registerSubsystem(timelineEngine);
    scheduler.registerSubsystem(scriptRuntime);

    scheduler.start();
    _initialized = true;
  }

  void shutdown() {
    scheduler.stop();
    _initialized = false;
  }

  // Syntactic sugar to register new AI engines easily
  void registerEngine(CognitiveSubsystem engine) {
    scheduler.registerSubsystem(engine);
  }
}
