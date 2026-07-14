const fs = require('fs');

function fixPublish(file) {
  let content = fs.readFileSync(file, 'utf8');
  content = content.replace(/EventBus\(\)\.publish\('([^']+)',\s*(\{.*?\})\);/g, "EventBus().publish(GenericEvent('$1', payload: $2));");
  content = content.replace(/EventBus\(\)\.publish\('([^']+)'\);/g, "EventBus().publish(GenericEvent('$1'));");
  
  // also fix listen
  content = content.replace(/EventBus\(\)\.stream\.where\(\(e\) => e\.runtimeType\.toString\(\) == '([^']+)'\)\.listen\(\(e\) => _([^ ]+)\(e\)\)/g, "EventBus().stream.where((e) => e is GenericEvent && e.type == '$1').listen((e) => _$2(e as GenericEvent))");
  content = content.replace(/EventBus\(\)\.stream\.listen\(\(e\) \{ if \(e\.runtimeType\.toString\(\) == '([^']+)'\.toString\(\)\) \{ _([^ ]+)\(e\); \} \}\)/g, "EventBus().stream.where((e) => e is GenericEvent && e.type == '$1').listen((e) => _$2(e as GenericEvent))");
  content = content.replace(/EventBus\(\)\.stream\.listen\(\(e\) \{ if \(e\.runtimeType\.toString\(\) == '([^']+)'\.toString\(\)\) \{ ([^ ]+)\(e\); \} \}\)/g, "EventBus().stream.where((e) => e is GenericEvent && e.type == '$1').listen((e) => $2(e as GenericEvent))");
  
  fs.writeFileSync(file, content);
}

fixPublish('lib/presentation/screens/ai_chat_panel.dart');
fixPublish('lib/presentation/screens/canvas_screen.dart');
fixPublish('lib/presentation/screens/canvas/canvas_widget.dart');
fixPublish('lib/core/event_logger.dart');

// We also need to define GenericEvent in base_event.dart
let baseEventPath = 'lib/core/events/base_event.dart';
let baseEvent = fs.readFileSync(baseEventPath, 'utf8');
if (!baseEvent.includes('class GenericEvent')) {
  baseEvent += "\n\nclass GenericEvent extends BaseEvent {\n  final String type;\n  final dynamic payload;\n  const GenericEvent(this.type, {this.payload}) : super.appStarted(); // Mock super call if needed\n}\n";
  fs.writeFileSync(baseEventPath, baseEvent);
}

console.log('Fixed publish');
