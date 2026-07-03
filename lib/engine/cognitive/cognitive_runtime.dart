import 'task_scheduler.dart';
import 'spatial_memory.dart';
import 'attention_engine.dart';
import 'avatar_engine.dart';
import 'prediction_engine.dart';
import 'physics_engine.dart';
import 'morph_engine.dart';
import 'timeline_engine.dart';
import 'script_runtime.dart';

class CognitiveRuntime {
  static final CognitiveRuntime _instance = CognitiveRuntime._internal();
  factory CognitiveRuntime() => _instance;
  
  late final TaskScheduler scheduler;
  late final SpatialMemory spatialMemory;
  late final AttentionEngine attentionEngine;
  late final AvatarEngine avatarEngine;
  late final PredictionEngine predictionEngine;
  late final PhysicsEngine physicsEngine;
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
    physicsEngine = PhysicsEngine();
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
