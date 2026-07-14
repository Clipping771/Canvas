import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/core/models/tool_type.dart';

void main() {
  group('AI Feature Pipeline Proof of Work', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test('1. Physics engine toggles properly via apply_gravity', () {
      final container = ProviderContainer();
      final notifier = container.read(drawingProvider.notifier);

      // Add a stroke
      notifier.addStrokes([
        Stroke(
          points: [const Offset(10, 10)],
          color: Colors.black,
          size: 2.0,
          toolType: ToolType.pen,
          groupId: 'target_group',
        ),
      ]);

      // Initially physics is disabled
      final strokes1 = container.read(drawingProvider).strokes;
      expect(strokes1.first.physicsEnabled, false);

      // Apply gravity
      notifier.applyGravityToGroup('target_group');

      // Assert physics is enabled
      final strokes2 = container.read(drawingProvider).strokes;
      expect(strokes2.first.physicsEnabled, true);
      debugPrint(
        "✅ apply_gravity successfully activates physics simulation on target objects.",
      );
    });

    test('2. eraseRect handles proper deletion', () {
      final container = ProviderContainer();
      final notifier = container.read(drawingProvider.notifier);
      // Add strokes
      notifier.addStrokes([
        Stroke(
          points: [const Offset(50, 50), const Offset(100, 100)],
          color: Colors.black,
          size: 2.0,
          toolType: ToolType.pen,
        ),
      ]);

      expect(container.read(drawingProvider).strokes.length, 1);

      // Erase within bounds
      notifier.eraseRect(const Rect.fromLTRB(40, 40, 110, 110));

      expect(container.read(drawingProvider).strokes.length, 0);
      debugPrint("✅ erase_rect correctly computes bounds and deletes objects.");
    });
  });
}
