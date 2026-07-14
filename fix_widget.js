const fs = require('fs');

// ============================================================
// Fix canvas_widget.dart
// ============================================================
let widgetPath = 'lib/presentation/screens/canvas/canvas_widget.dart';
let widget = fs.readFileSync(widgetPath, 'utf8');

// Fix imports
widget = widget
  .replace("import '../engine/canvas_exporter.dart';", "import 'package:vinci_board/core/canvas/canvas_exporter.dart';")
  .replace("import '../models/stroke.dart';", "import 'package:vinci_board/core/models/stroke.dart';")
  .replace("import '../models/tool_type.dart';", "import 'package:vinci_board/core/models/tool_type.dart';")
  .replace("import '../providers/drawing_provider.dart';", "import 'package:vinci_board/presentation/providers/drawing_provider.dart';")
  .replace("import '../providers/ai_chat_provider.dart';", "import 'package:vinci_board/presentation/providers/ai_chat_provider.dart';")
  .replace("import '../providers/settings_provider.dart';", "import 'package:vinci_board/presentation/providers/settings_provider.dart';")
  .replace("import '../providers/spatial_registry_provider.dart';", "import 'package:vinci_board/presentation/providers/spatial_registry_provider.dart';")
  .replace("import '../services/chemistry_service.dart';", "import 'package:vinci_board/engines/chemistry/chemistry_service.dart';")
  .replace("import '../engine/weight_controller.dart';", "import 'package:vinci_board/core/canvas/weight_controller.dart';")
  .replace("import '../core/theme/da_vinci_theme.dart';", "import 'package:vinci_board/core/theme/da_vinci_theme.dart';")
  .replace("import '../core/widgets/glass_container.dart';", "import 'package:vinci_board/core/widgets/glass_container.dart';")
  .replace("import '../engine/semantic_camera.dart';", "import 'package:vinci_board/core/canvas/semantic_camera.dart';")
  .replace("import '../engine/drawing_painter.dart';", "import 'package:vinci_board/presentation/painters/drawing_painter.dart';")
  .replace("import '../engine/selection_overlay.dart';", "import 'package:vinci_board/presentation/painters/selection_overlay.dart';")
  .replace("import '../engine/logic/models/circuit_component.dart';", "import 'package:vinci_board/engines/logic/models/circuit_component.dart';")
  .replace("import '../engine/cognitive/cognitive_runtime.dart';", "import 'package:vinci_board/engines/cognitive/cognitive_runtime.dart';")
  .replace("import '../engine/cognitive/avatar_engine.dart';", "import 'package:vinci_board/engines/cognitive/avatar_engine.dart';")
  .replace("import '../models/spatial_node.dart';", "import 'package:vinci_board/core/models/spatial_node.dart';")
  .replace("import '../engines/ai/ai_spawn_manager.dart';", "import 'package:vinci_board/engines/ai/ai_spawn_manager.dart';")
  .replace("import '../core/models/ai/spawn_strategy.dart';", "import 'package:vinci_board/core/models/ai/spawn_strategy.dart';")
  .replace("import '../core/models/ai/spawn_location.dart';", "import 'package:vinci_board/core/models/ai/spawn_location.dart';")
  .replace("import '../core/event_bus.dart';", "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';");

// Fix EventBus subscribe call
// Original: EventBus().subscribe(EventType.aiSpawnCompleted, (event) { ... });
widget = widget.replace(
  /EventBus\(\)\.subscribe\(EventType\.aiSpawnCompleted,\s*\(event\)\s*\{([\s\S]*?)\}\s*\)/,
  `EventBus().stream.where((e) => e is GenericEvent && e.type == 'aiSpawnCompleted').listen((e) {
      final event = e as GenericEvent;$1})`
);

// Fix all EventType.xyz -> string, and subscribe -> stream.listen
widget = widget.replace(/EventType\.([a-zA-Z0-9_]+)/g, "'$1'");
widget = widget.replace(/EventBus\(\)\.subscribe\('([^']+)',\s*\(([^)]*)\)\s*\{/g, "EventBus().stream.where((e) => e is GenericEvent && e.type == '$1').listen(($2) {");

// Fix EventBus().publish(...)
widget = widget.replace(/EventBus\(\)\.publish\('([^']+)',\s*(\{[^}]*\})\)/g, "EventBus().publish(BaseEvent.generic('$1', payload: $2))");
widget = widget.replace(/EventBus\(\)\.publish\('([^']+)'\)/g, "EventBus().publish(const BaseEvent.generic('$1'))");

// Fix event.payload
// After casting, event is GenericEvent which has .payload
// These are likely already correct after the listen lambda change above.

fs.writeFileSync(widgetPath, widget, 'utf8');
console.log('Fixed canvas_widget.dart');

// ============================================================
// Fix simulation_scheduler.dart
// ============================================================
let schedulerPath = 'lib/engines/logic/core/simulation_scheduler.dart';
let scheduler = fs.readFileSync(schedulerPath, 'utf8');

// Fix: Circuit'simulationTick' -> 'simulationTick'
scheduler = scheduler.replace(/Circuit'([^']+)'/g, "'$1'");
// Also fix any remaining EventType.xyz
scheduler = scheduler.replace(/EventType\.([a-zA-Z0-9_]+)/g, "'$1'");

fs.writeFileSync(schedulerPath, scheduler, 'utf8');
console.log('Fixed simulation_scheduler.dart');
