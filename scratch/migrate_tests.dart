import 'package:flutter/foundation.dart';
import 'dart:io';

void main() async {
  // Update imports in test directory and root
  final dirs = [Directory('test'), Directory('.')];

  for (final dir in dirs) {
    if (!dir.existsSync()) continue;

    final dartFiles = dir
        .listSync(recursive: dir.path != '.')
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              (dir.path != '.' || !f.path.contains(Platform.pathSeparator)),
        );

    for (final file in dartFiles) {
      // Don't touch migrate.dart itself
      if (file.path.contains('migrate.dart')) continue;

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

  debugPrint('Test migration completed successfully.');
}
