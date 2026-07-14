const fs = require('fs');

// Fix canvas_screen.dart
let canvasPath = 'lib/presentation/screens/canvas_screen.dart';
let canvasContent = fs.readFileSync(canvasPath, 'utf8');
canvasContent = canvasContent.replace("import '../engine/physics_engine.dart';", "import 'package:vinci_board/engines/physics/physics_engine.dart';");
canvasContent = canvasContent.replace(/event\.payload/g, 'event.toString()');
fs.writeFileSync(canvasPath, canvasContent, 'utf8');

// Fix lms_provider.dart
let lmsPath = 'lib/presentation/providers/lms_provider.dart';
let lmsContent = fs.readFileSync(lmsPath, 'utf8');
lmsContent = lmsContent.replace(/state\.currentLesson/g, 'this.state.currentLesson');
lmsContent = lmsContent.replace(/state\.adapter/g, 'this.state.adapter');
fs.writeFileSync(lmsPath, lmsContent, 'utf8');
