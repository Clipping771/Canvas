import 'package:flutter/foundation.dart';
import 'dart:io';

void main() async {
  // 1. Create target directories
  final dirs = [
    'lib/presentation/screens/canvas',
    'lib/core/canvas',
    'lib/engines/physics/physics_v2',
    'lib/engines/sound',
    'lib/engines/ai',
    'lib/engines/biology',
    'lib/engines/chemistry',
    'lib/engines/cognitive',
    'lib/engines/knowledge',
    'lib/engines/logic',
    'lib/engines/math',
  ];
  for (final dir in dirs) {
    await Directory(dir).create(recursive: true);
  }

  // 2. Move files
  final moves = {
    // Canvas UI
    'lib/engine/canvas_widget.dart':
        'lib/presentation/screens/canvas/canvas_widget.dart',
    'lib/engine/drawing_painter.dart':
        'lib/presentation/screens/canvas/drawing_painter.dart',
    'lib/engine/selection_overlay.dart':
        'lib/presentation/screens/canvas/selection_overlay.dart',

    // Canvas Core
    'lib/engine/canvas_controller.dart':
        'lib/core/canvas/canvas_controller.dart',
    'lib/engine/canvas_exporter.dart': 'lib/core/canvas/canvas_exporter.dart',
    'lib/engine/layout_memory.dart': 'lib/core/canvas/layout_memory.dart',
    'lib/engine/semantic_camera.dart': 'lib/core/canvas/semantic_camera.dart',
    'lib/engine/spatial_layout_engine.dart':
        'lib/core/canvas/spatial_layout_engine.dart',
    'lib/engine/weight_controller.dart':
        'lib/core/canvas/weight_controller.dart',

    // Engines
    'lib/engine/particle_engine.dart':
        'lib/engines/physics/particle_engine.dart',
    'lib/engine/physics_engine.dart': 'lib/engines/physics/physics_engine.dart',
    'lib/engine/sound_engine.dart': 'lib/engines/sound/sound_engine.dart',
    'lib/engine/shape_recognizer.dart': 'lib/engines/ai/shape_recognizer.dart',

    // Folders
    'lib/engine/physics_v2': 'lib/engines/physics/physics_v2',
    'lib/engine/biology': 'lib/engines/biology',
    'lib/engine/chemistry': 'lib/engines/chemistry',
    'lib/engine/cognitive': 'lib/engines/cognitive',
    'lib/engine/knowledge': 'lib/engines/knowledge',
    'lib/engine/logic': 'lib/engines/logic',
    'lib/engine/math': 'lib/engines/math',
    'lib/engine/ai': 'lib/engines/ai',
  };

  for (final entry in moves.entries) {
    final entity = FileSystemEntity.typeSync(entry.key);
    if (entity == FileSystemEntityType.directory) {
      final dir = Directory(entry.key);
      if (dir.existsSync()) {
        final list = dir.listSync(recursive: true);
        for (final item in list) {
          if (item is File) {
            final relativePath = item.path.substring(dir.path.length + 1);
            final destPath = '${entry.value}/$relativePath';
            await File(destPath).parent.create(recursive: true);
            await item.rename(destPath);
          }
        }
      }
    } else if (entity == FileSystemEntityType.file) {
      final file = File(entry.key);
      if (file.existsSync()) {
        await file.rename(entry.value);
      }
    }
  }

  // Delete old engine dir
  final dir = Directory('lib/engine');
  if (dir.existsSync()) {
    try {
      await dir.delete(recursive: true);
    } catch (e) { /* ignore */ }
  }

  // 3. Update imports
  final allDirs = [Directory('lib'), Directory('test'), Directory('.')];
  for (final searchDir in allDirs) {
    if (!searchDir.existsSync()) continue;
    final dartFiles = searchDir
        .listSync(recursive: searchDir.path != '.')
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              (searchDir.path != '.' ||
                  !f.path.contains(Platform.pathSeparator)),
        );

    for (final file in dartFiles) {
      if (file.path.contains('migrate_engine.dart')) continue;

      var content = await file.readAsString();

      final replacements = {
        'package:vinci_board/engine/canvas_widget.dart':
            'package:vinci_board/presentation/screens/canvas/canvas_widget.dart',
        'package:vinci_board/engine/drawing_painter.dart':
            'package:vinci_board/presentation/screens/canvas/drawing_painter.dart',
        'package:vinci_board/engine/selection_overlay.dart':
            'package:vinci_board/presentation/screens/canvas/selection_overlay.dart',

        'package:vinci_board/engine/canvas_controller.dart':
            'package:vinci_board/core/canvas/canvas_controller.dart',
        'package:vinci_board/engine/canvas_exporter.dart':
            'package:vinci_board/core/canvas/canvas_exporter.dart',
        'package:vinci_board/engine/layout_memory.dart':
            'package:vinci_board/core/canvas/layout_memory.dart',
        'package:vinci_board/engine/semantic_camera.dart':
            'package:vinci_board/core/canvas/semantic_camera.dart',
        'package:vinci_board/engine/spatial_layout_engine.dart':
            'package:vinci_board/core/canvas/spatial_layout_engine.dart',
        'package:vinci_board/engine/weight_controller.dart':
            'package:vinci_board/core/canvas/weight_controller.dart',

        'package:vinci_board/engine/particle_engine.dart':
            'package:vinci_board/engines/physics/particle_engine.dart',
        'package:vinci_board/engine/physics_engine.dart':
            'package:vinci_board/engines/physics/physics_engine.dart',
        'package:vinci_board/engine/sound_engine.dart':
            'package:vinci_board/engines/sound/sound_engine.dart',
        'package:vinci_board/engine/shape_recognizer.dart':
            'package:vinci_board/engines/ai/shape_recognizer.dart',

        'package:vinci_board/engine/physics_v2/':
            'package:vinci_board/engines/physics/physics_v2/',
        'package:vinci_board/engine/biology/':
            'package:vinci_board/engines/biology/',
        'package:vinci_board/engine/chemistry/':
            'package:vinci_board/engines/chemistry/',
        'package:vinci_board/engine/cognitive/':
            'package:vinci_board/engines/cognitive/',
        'package:vinci_board/engine/knowledge/':
            'package:vinci_board/engines/knowledge/',
        'package:vinci_board/engine/logic/':
            'package:vinci_board/engines/logic/',
        'package:vinci_board/engine/math/': 'package:vinci_board/engines/math/',
        'package:vinci_board/engine/ai/': 'package:vinci_board/engines/ai/',

        // common relative imports to engine inside engine/
        "'../biology/": "'../../biology/",
        "'../math/": "'../../math/",
        "'../logic/": "'../../logic/",
        "'../physics_v2/": "'../../physics/physics_v2/",
      };

      String newContent = content;
      for (final entry in replacements.entries) {
        newContent = newContent.replaceAll(entry.key, entry.value);
      }

      if (newContent != content) {
        await file.writeAsString(newContent);
      }
    }
  }

  debugPrint('Engine migration completed successfully.');
}
