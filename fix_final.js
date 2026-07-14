const fs = require('fs');
const path = require('path');

// ============================================================
// 1. Fix ai_chat_panel.dart -- restore properly migrated version
// ============================================================
let chatPath = 'lib/presentation/screens/ai_chat_panel.dart';
let chat = fs.readFileSync(chatPath, 'utf8');

// Fix the old EventType.cancelGeneration subscribe
chat = chat.replace(
  `    _cancelSub = EventBus().subscribe(EventType.cancelGeneration, (_) {`,
  `    _cancelSub = EventBus().stream.where((e) => e is GenericEvent && e.type == 'cancelGeneration').listen((_) {`
);
// Fix remaining EventType references inside publish calls
chat = chat.replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+),\s*(.+?)\)/g, "EventBus().publish(BaseEvent.generic('$1', payload: $2))");
// EventBus().publish(EventType.xxx) with no payload
chat = chat.replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+)\)/g, "EventBus().publish(const BaseEvent.generic('$1'))");

// Make sure audioplayers is imported
if (!chat.includes("import 'package:audioplayers/audioplayers.dart'")) {
  chat = chat.replace(
    "import 'dart:async';",
    "import 'dart:async';\nimport 'package:audioplayers/audioplayers.dart';"
  );
}

// Make sure base_event is imported
if (!chat.includes('base_event.dart')) {
  chat = chat.replace(
    "import 'package:vinci_board/core/event_bus.dart';",
    "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';"
  );
}

fs.writeFileSync(chatPath, chat, 'utf8');
console.log('Fixed ai_chat_panel.dart');

// ============================================================
// 2. Fix canvas_widget.dart broken imports
// ============================================================
let widgetPath = 'lib/presentation/screens/canvas/canvas_widget.dart';
let widget = fs.readFileSync(widgetPath, 'utf8');

widget = widget
  .replace("import '../widgets/weather_widget.dart';", "import 'package:vinci_board/presentation/widgets/weather_widget.dart';")
  .replace("import '../widgets/chemistry_widget.dart';", "import 'package:vinci_board/presentation/widgets/chemistry_widget.dart';")
  .replace("import 'logic/tesla_engine.dart';", "import 'package:vinci_board/engines/logic/tesla_engine.dart';")
  .replace("import '../engine/canvas_widget.dart';", '')  // self-import if any
  .replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+),\s*(.+?)\)/g, "EventBus().publish(BaseEvent.generic('$1', payload: $2))")
  .replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+)\)/g, "EventBus().publish(const BaseEvent.generic('$1'))");

if (!chat.includes('base_event.dart')) {
  widget = widget.replace(
    "import 'package:vinci_board/core/event_bus.dart';",
    "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';"
  );
}

fs.writeFileSync(widgetPath, widget, 'utf8');
console.log('Fixed canvas_widget.dart');

// ============================================================
// 3. Fix drawing_provider.dart
// ============================================================
let drawingPath = 'lib/presentation/providers/drawing_provider.dart';
let drawing = fs.readFileSync(drawingPath, 'utf8');

drawing = drawing.replace(
  "import '../engine/physics_engine.dart';",
  "import 'package:vinci_board/engines/physics/physics_engine.dart';"
);

fs.writeFileSync(drawingPath, drawing, 'utf8');
console.log('Fixed drawing_provider.dart');

// ============================================================
// 4. Fix intent_router.dart EventBus publish calls
// ============================================================
let intentPath = 'lib/core/intent_router.dart';
let intent = fs.readFileSync(intentPath, 'utf8');

intent = intent
  .replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+),\s*(.+?)\)/g, "EventBus().publish(BaseEvent.generic('$1', payload: $2))")
  .replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+)\)/g, "EventBus().publish(const BaseEvent.generic('$1'))");

if (!intent.includes('base_event.dart')) {
  intent = intent.replace(
    "import 'event_bus.dart';",
    "import 'event_bus.dart';\nimport 'events/base_event.dart';"
  );
}

fs.writeFileSync(intentPath, intent, 'utf8');
console.log('Fixed intent_router.dart');

// ============================================================
// 5. Fix ai_spawn_manager.dart EventBus publish calls
// ============================================================
let spawnPath = 'lib/engines/ai/ai_spawn_manager.dart';
let spawn = fs.readFileSync(spawnPath, 'utf8');

spawn = spawn
  .replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+),\s*(.+?)\)/g, "EventBus().publish(BaseEvent.generic('$1', payload: $2))")
  .replace(/EventBus\(\)\.publish\(EventType\.([a-zA-Z0-9_]+)\)/g, "EventBus().publish(const BaseEvent.generic('$1'))");

if (!spawn.includes('base_event.dart')) {
  spawn = spawn.replace(
    "import 'package:vinci_board/core/event_bus.dart';",
    "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';"
  );
}

fs.writeFileSync(spawnPath, spawn, 'utf8');
console.log('Fixed ai_spawn_manager.dart');

// ============================================================
// 6. Fix physics_engine.dart event.payload
// ============================================================
let physicsPath = 'lib/engines/physics/physics_engine.dart';
let physics = fs.readFileSync(physicsPath, 'utf8');

// event.payload -> (event as GenericEvent).payload
physics = physics.replace(/event\.payload/g, '(event is GenericEvent ? event.payload : null)');

if (!physics.includes('base_event.dart')) {
  physics = physics.replace(
    "import 'package:vinci_board/core/event_bus.dart';",
    "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';"
  );
}

fs.writeFileSync(physicsPath, physics, 'utf8');
console.log('Fixed physics_engine.dart');

// ============================================================
// 7. Fix canvas_screen.dart event.toString() (was payload, now cast)
// ============================================================
let canvasPath = 'lib/presentation/screens/canvas_screen.dart';
let canvas = fs.readFileSync(canvasPath, 'utf8');

// event.toString() is used to access old payload data -> use (event as GenericEvent).payload
canvas = canvas.replace(/\(event\.toString\(\)\)/g, '((event is GenericEvent ? event.payload : null))');

fs.writeFileSync(canvasPath, canvas, 'utf8');
console.log('Fixed canvas_screen.dart');

// ============================================================
// 8. Fix test_ai.dart stale imports
// ============================================================
let testAiPath = 'test_ai.dart';
let testAi = fs.readFileSync(testAiPath, 'utf8');
testAi = testAi
  .replace(/import 'package:vinci_board\/services\/ai_agent_service\.dart';/g, "import 'package:vinci_board/adapters/ai/ai_agent_service.dart';")
  .replace(/import 'package:vinci_board\/models\/ai_provider\.dart';/g, "import 'package:vinci_board/core/models/ai_provider.dart';");
fs.writeFileSync(testAiPath, testAi, 'utf8');
console.log('Fixed test_ai.dart');

console.log('\nAll targeted fixes applied!');
