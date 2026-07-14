const fs = require('fs');

// ============================================================
// 1. Fix event_logger.dart: remove event.timestamp
// ============================================================
let logPath = 'lib/core/event_logger.dart';
let log = fs.readFileSync(logPath, 'utf8');
log = log.replace(
  "debugPrint('[EventLogger] ${event.timestamp.toIso8601String()} - ${event.runtimeType.toString()}$payloadStr');",
  "debugPrint('[EventLogger] ${DateTime.now().toIso8601String()} - ${event.runtimeType.toString()}$payloadStr');"
);
fs.writeFileSync(logPath, log, 'utf8');
console.log('Fixed event_logger.dart');

// ============================================================
// 2. Fix intent_router.dart: publish(String, payload) -> publish(BaseEvent.generic(...))
// ============================================================
let intentPath = 'lib/core/intent_router.dart';
let intent = fs.readFileSync(intentPath, 'utf8');
intent = intent
  .replace("EventBus().publish('aiActionDispatched', intent.payload);", "EventBus().publish(BaseEvent.generic('aiActionDispatched', payload: intent.payload));")
  .replace("EventBus().publish('physicsTriggered', intent.payload);", "EventBus().publish(BaseEvent.generic('physicsTriggered', payload: intent.payload));")
  .replace("EventBus().publish('canvasUpdated', intent.payload);", "EventBus().publish(BaseEvent.generic('canvasUpdated', payload: intent.payload));")
  .replace("EventBus().publish('systemError', {'error': e.toString(), 'action': intent.actionName});", "EventBus().publish(BaseEvent.generic('systemError', payload: {'error': e.toString(), 'action': intent.actionName}));");
fs.writeFileSync(intentPath, intent, 'utf8');
console.log('Fixed intent_router.dart');

// ============================================================
// 3. Fix ai_spawn_manager.dart: publish(String, payload) -> publish(BaseEvent.generic(...))
// ============================================================
let spawnPath = 'lib/engines/ai/ai_spawn_manager.dart';
let spawn = fs.readFileSync(spawnPath, 'utf8');
spawn = spawn.replace(
  "EventBus().publish('aiSpawnCompleted', location.position);",
  "EventBus().publish(BaseEvent.generic('aiSpawnCompleted', payload: location.position));"
);
fs.writeFileSync(spawnPath, spawn, 'utf8');
console.log('Fixed ai_spawn_manager.dart');

// ============================================================
// 4. Fix canvas_screen.dart: event.toString()['key'] -> (event as GenericEvent).payload
// ============================================================
let canvasPath = 'lib/presentation/screens/canvas_screen.dart';
let canvas = fs.readFileSync(canvasPath, 'utf8');
canvas = canvas
  .replace(
    "    final intent = event.toString()['intent'] as CameraIntent?;",
    "    final payload = (event is GenericEvent ? event.payload : null) as Map<String, dynamic>?;\n    final intent = payload?['intent'] as CameraIntent?;"
  )
  .replace(
    "    if (event.toString()['action'] == 'trigger_quiz') {",
    "    final payload = (event is GenericEvent ? event.payload : null) as Map<String, dynamic>?;\n    if (payload?['action'] == 'trigger_quiz') {"
  )
  .replace(
    "          quizData: event.toString(),",
    "          quizData: payload ?? {},"
  );
fs.writeFileSync(canvasPath, canvas, 'utf8');
console.log('Fixed canvas_screen.dart');

console.log('\nAll fixes applied!');
