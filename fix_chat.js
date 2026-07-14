const fs = require('fs');

// Fix ai_chat_panel.dart
let chatPath = 'lib/presentation/screens/ai_chat_panel.dart';
let chat = fs.readFileSync(chatPath, 'utf8');

// 1. Fix the imports to use new package paths
chat = chat
  .replace("import '../engine/canvas_exporter.dart';", "import 'package:vinci_board/core/canvas/canvas_exporter.dart';")
  .replace("import '../models/stroke.dart';", "import '../../core/models/stroke.dart';")
  .replace("import '../models/tool_type.dart';", "import '../../core/models/tool_type.dart';")
  .replace("import '../providers/drawing_provider.dart';", "import '../../presentation/providers/drawing_provider.dart';")
  .replace("import '../providers/settings_provider.dart';", "import '../../presentation/providers/settings_provider.dart';")
  .replace("import '../providers/ai_chat_provider.dart';", "import '../../presentation/providers/ai_chat_provider.dart';")
  .replace("import '../services/ai_agent_service.dart';", "import 'package:vinci_board/adapters/ai/ai_agent_service.dart';")
  .replace("import '../services/memory_service.dart';", "import 'package:vinci_board/engines/memory/memory_service.dart';")
  .replace("import '../services/plantuml_service.dart';", "import 'package:vinci_board/adapters/export/plantuml_service.dart';")
  .replace("import '../services/chemistry_service.dart';", "import 'package:vinci_board/engines/chemistry/chemistry_service.dart';")
  .replace("import '../utils/ai_stroke_generator.dart';", "import 'package:vinci_board/adapters/ai/ai_stroke_generator.dart';")
  .replace("import '../utils/sketch_templates.dart';", "import 'package:vinci_board/core/utils/sketch_templates.dart';")
  .replace("import '../models/spatial_node.dart';", "import '../../core/models/spatial_node.dart';")
  .replace("import '../engine/weight_controller.dart';", "import 'package:vinci_board/core/canvas/weight_controller.dart';")
  .replace("import '../core/theme/da_vinci_theme.dart';", "import 'package:vinci_board/core/theme/da_vinci_theme.dart';")
  .replace("import '../core/widgets/glass_container.dart';", "import 'package:vinci_board/core/widgets/glass_container.dart';")
  .replace("import '../engine/semantic_camera.dart';", "import 'package:vinci_board/core/canvas/semantic_camera.dart';")
  .replace("import '../providers/spatial_registry_provider.dart';", "import '../../presentation/providers/spatial_registry_provider.dart';")
  .replace("import '../core/event_bus.dart';", "import 'package:vinci_board/core/event_bus.dart';\nimport 'package:vinci_board/core/events/base_event.dart';")
  .replace("import '../engine/cognitive/cognitive_runtime.dart';", "import 'package:vinci_board/engines/cognitive/cognitive_runtime.dart';")
  .replace("import '../engine/cognitive/avatar_engine.dart';", "import 'package:vinci_board/engines/cognitive/avatar_engine.dart';")
  .replace("import '../engine/logic/models/circuit_component.dart';", "import 'package:vinci_board/engines/logic/models/circuit_component.dart';")
  .replace("import '../engines/ai/ai_spawn_manager.dart';", "import 'package:vinci_board/engines/ai/ai_spawn_manager.dart';")
  .replace("import '../core/models/ai/spawn_strategy.dart';", "import '../../core/models/ai/spawn_strategy.dart';")
  .replace("import '../core/models/ai/spawn_location.dart';", "import '../../core/models/ai/spawn_location.dart';")
  .replace("import 'package:audioplayers/audioplayers.dart';", "import 'package:audioplayers/audioplayers.dart';");

// 2. Fix the EventBus subscription
chat = chat.replace(
  `    _cancelSub = EventBus().subscribe(EventType.cancelGeneration, (_) {
      if (_isTyping) {
        setState(() {
          _cancelRequested = true;
          AiAgentService.cancelRequest();
        });
        if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
          _cancelCompleter!.complete("Cancelled by user");
        }
      }
    });`,
  `    _cancelSub = EventBus().stream.where((e) => e is GenericEvent && e.type == 'cancelGeneration').listen((_) {
      if (_isTyping) {
        setState(() {
          _cancelRequested = true;
          AiAgentService.cancelRequest();
        });
        if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
          _cancelCompleter!.complete("Cancelled by user");
        }
      }
    });`
);

// 3. Add AudioPlayer field
if (!chat.includes('_popPlayer')) {
  chat = chat.replace(
    '  StreamSubscription? _cancelSub;',
    '  final AudioPlayer _popPlayer = AudioPlayer();\n  StreamSubscription? _cancelSub;'
  );
  // Add popPlayer init
  chat = chat.replace(
    `    _cancelSub = EventBus()`,
    `    _popPlayer.setSource(AssetSource('pop.mp3')).catchError((_) {});\n    _cancelSub = EventBus()`
  );
  // Add popPlayer dispose
  chat = chat.replace(
    '  void dispose() {\n    _textController.dispose();',
    '  void dispose() {\n    _popPlayer.dispose();\n    _textController.dispose();'
  );
}

// 4. Fix all EventBus.publish references
chat = chat.replace(/EventBus\(\)\.publish\('([^']+)',\s*(\{[^)]*\})\)/g, "EventBus().publish(const BaseEvent.generic('$1', payload: $2))");
chat = chat.replace(/EventBus\(\)\.publish\('([^']+)'\)/g, "EventBus().publish(const BaseEvent.generic('$1'))");

fs.writeFileSync(chatPath, chat, 'utf8');
console.log('Fixed ai_chat_panel.dart');
