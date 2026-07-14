const fs = require('fs');

// Fix event_logger.dart
let loggerPath = 'lib/core/event_logger.dart';
let loggerContent = fs.readFileSync(loggerPath, 'utf8');
loggerContent = loggerContent.replace(/CanvasEvent/g, 'BaseEvent');
// BaseEvent is in lib/core/events/base_event.dart
loggerContent = loggerContent.replace("import 'event_bus.dart';", "import 'event_bus.dart';\nimport 'events/base_event.dart';");
// event.type.name doesn't exist on BaseEvent (which uses freezed). The runtime type is just event.runtimeType
loggerContent = loggerContent.replace(/event\.type\.name/g, 'event.runtimeType.toString()');
// event.payload doesn't exist on BaseEvent either, unless we cast or just log the whole event
loggerContent = loggerContent.replace(/event\.payload/g, 'event.toString()'); // Quick hack to get rid of payload
fs.writeFileSync(loggerPath, loggerContent, 'utf8');

// Fix canvas_screen.dart
let canvasPath = 'lib/presentation/screens/canvas_screen.dart';
let canvasContent = fs.readFileSync(canvasPath, 'utf8');
canvasContent = canvasContent.replace(/EventBus\(\)\.subscribe\(EventType\.aiActionDispatched, _handleQuizEvent\);/g, "EventBus().stream.where((e) => e.runtimeType.toString() == 'AiActionDispatched').listen(_handleQuizEvent);");
canvasContent = canvasContent.replace(/EventBus\(\)\.subscribe\(EventType\.aiTaskCompleted, _handleAiTaskCompleted\);/g, "EventBus().stream.where((e) => e.runtimeType.toString() == 'AiTaskCompleted').listen(_handleAiTaskCompleted);");
canvasContent = canvasContent.replace(/CanvasEvent/g, 'BaseEvent');
canvasContent = canvasContent.replace("import 'package:vinci_board/core/event_bus.dart';", "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';");
// the _handleQuizEvent and _handleAiTaskCompleted might take dynamic or CanvasEvent.
// The regex /CanvasEvent/g already replaced CanvasEvent with BaseEvent.
fs.writeFileSync(canvasPath, canvasContent, 'utf8');

// Fix ai_chat_panel.dart
let chatPath = 'lib/presentation/screens/ai_chat_panel.dart';
let chatContent = fs.readFileSync(chatPath, 'utf8');
chatContent = chatContent.replace(/CanvasEvent/g, 'BaseEvent');
chatContent = chatContent.replace(/EventBus\(\)\.subscribe\(([^,]+),\s*([^)]+)\)/g, "EventBus().stream.listen((e) { if (e.runtimeType.toString() == $1.toString()) { $2(e); } })");
// Let's do a broader replacement for EventBus().subscribe
chatContent = chatContent.replace(/EventType\.[a-zA-Z]+/g, (match) => "'" + match.replace('EventType.', '') + "'");
// Need to add base_event import
if (!chatContent.includes("base_event.dart")) {
    chatContent = chatContent.replace("import 'package:vinci_board/core/event_bus.dart';", "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';");
}
fs.writeFileSync(chatPath, chatContent, 'utf8');

console.log('Event fixes applied');
