import 'package:flutter/foundation.dart';
import 'dart:io';

void main() async {
  final libDir = Directory('lib');

  // 1. Create directories
  final dirs = [
    'lib/core/models',
    'lib/presentation/screens',
    'lib/presentation/widgets',
    'lib/presentation/providers',
    'lib/adapters/storage',
    'lib/adapters/ai',
    'lib/adapters/device',
    'lib/engines/chemistry',
    'lib/engines/trivia',
    'lib/engines/monetization',
    'lib/adapters/export',
    'lib/engines/memory',
    'lib/core/utils',
  ];
  for (final dir in dirs) {
    await Directory(dir).create(recursive: true);
  }

  // 2. Move files
  final moves = {
    // Models
    'lib/models': 'lib/core/models',
    // Presentation
    'lib/screens': 'lib/presentation/screens',
    'lib/widgets': 'lib/presentation/widgets',
    'lib/providers': 'lib/presentation/providers',
    // Adapters - AI
    'lib/services/ai_agent_service.dart':
        'lib/adapters/ai/ai_agent_service.dart',
    'lib/services/ai_copilot_service.dart':
        'lib/adapters/ai/ai_copilot_service.dart',
    'lib/services/api_model_fetcher.dart':
        'lib/adapters/ai/api_model_fetcher.dart',
    'lib/utils/ai_stroke_generator.dart':
        'lib/adapters/ai/ai_stroke_generator.dart',
    // Adapters - Storage
    'lib/services/storage_service.dart':
        'lib/adapters/storage/storage_service.dart',
    'lib/services/cloud_sync_service.dart':
        'lib/adapters/storage/cloud_sync_service.dart',
    // Adapters - Device
    'lib/services/voice_recognition_service.dart':
        'lib/adapters/device/voice_recognition_service.dart',
    // Engines
    'lib/services/chemistry_service.dart':
        'lib/engines/chemistry/chemistry_service.dart',
    'lib/services/trivia_service.dart':
        'lib/engines/trivia/trivia_service.dart',
    'lib/services/monetization_service.dart':
        'lib/engines/monetization/monetization_service.dart',
    'lib/services/memory_service.dart':
        'lib/engines/memory/memory_service.dart',
    'lib/services/export_service.dart':
        'lib/adapters/export/export_service.dart',
    'lib/services/plantuml_service.dart':
        'lib/adapters/export/plantuml_service.dart',
    // Utils
    'lib/utils/city_matcher.dart': 'lib/core/utils/city_matcher.dart',
    'lib/utils/sketch_templates.dart': 'lib/core/utils/sketch_templates.dart',
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

  // Delete old dirs
  final oldDirs = [
    'lib/models',
    'lib/screens',
    'lib/widgets',
    'lib/providers',
    'lib/services',
    'lib/utils',
  ];
  for (final dirPath in oldDirs) {
    final dir = Directory(dirPath);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  // 3. Update imports
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    var content = await file.readAsString();

    final replacements = {
      'package:vinci_board/models/': 'package:vinci_board/core/models/',
      'package:vinci_board/screens/':
          'package:vinci_board/presentation/screens/',
      'package:vinci_board/widgets/':
          'package:vinci_board/presentation/widgets/',
      'package:vinci_board/providers/':
          'package:vinci_board/presentation/providers/',
      'package:vinci_board/services/ai_agent_service.dart':
          'package:vinci_board/adapters/ai/ai_agent_service.dart',
      'package:vinci_board/services/ai_copilot_service.dart':
          'package:vinci_board/adapters/ai/ai_copilot_service.dart',
      'package:vinci_board/services/api_model_fetcher.dart':
          'package:vinci_board/adapters/ai/api_model_fetcher.dart',
      'package:vinci_board/services/storage_service.dart':
          'package:vinci_board/adapters/storage/storage_service.dart',
      'package:vinci_board/services/cloud_sync_service.dart':
          'package:vinci_board/adapters/storage/cloud_sync_service.dart',
      'package:vinci_board/services/voice_recognition_service.dart':
          'package:vinci_board/adapters/device/voice_recognition_service.dart',
      'package:vinci_board/services/chemistry_service.dart':
          'package:vinci_board/engines/chemistry/chemistry_service.dart',
      'package:vinci_board/services/trivia_service.dart':
          'package:vinci_board/engines/trivia/trivia_service.dart',
      'package:vinci_board/services/monetization_service.dart':
          'package:vinci_board/engines/monetization/monetization_service.dart',
      'package:vinci_board/services/memory_service.dart':
          'package:vinci_board/engines/memory/memory_service.dart',
      'package:vinci_board/services/export_service.dart':
          'package:vinci_board/adapters/export/export_service.dart',
      'package:vinci_board/services/plantuml_service.dart':
          'package:vinci_board/adapters/export/plantuml_service.dart',
      'package:vinci_board/utils/ai_stroke_generator.dart':
          'package:vinci_board/adapters/ai/ai_stroke_generator.dart',
      'package:vinci_board/utils/city_matcher.dart':
          'package:vinci_board/core/utils/city_matcher.dart',
      'package:vinci_board/utils/sketch_templates.dart':
          'package:vinci_board/core/utils/sketch_templates.dart',

      // Basic relative import fixes
      "'../models/": "'../../core/models/",
      "'../screens/": "'../../presentation/screens/",
      "'../widgets/": "'../../presentation/widgets/",
      "'../providers/": "'../../presentation/providers/",
      "'../../models/": "'../../../core/models/",
      "'../../screens/": "'../../../presentation/screens/",
      "'../../widgets/": "'../../../presentation/widgets/",
      "'../../providers/": "'../../../presentation/providers/",
    };

    String newContent = content;
    for (final entry in replacements.entries) {
      newContent = newContent.replaceAll(entry.key, entry.value);
    }

    if (newContent != content) {
      await file.writeAsString(newContent);
    }
  }

  debugPrint('Migration completed successfully.');
}
