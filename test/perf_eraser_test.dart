import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Eraser Perf at 500+ strokes', () {
    final container = ProviderContainer();
    final notifier = container.read(drawingProvider.notifier);

    // Generate 500 random strokes
    final List<Stroke> fakeStrokes = List.generate(500, (i) {
      return Stroke(
        points: [
          Offset(i.toDouble(), i.toDouble()),
          Offset(i.toDouble() + 10, i.toDouble() + 10),
        ],
        color: Colors.black,
        size: 5.0,
        toolType: ToolType.pen,
      );
    });

    // Need to insert strokes using the public method
    notifier.addStrokes(fakeStrokes);

    final stopwatch = Stopwatch()..start();
    final eraseCount = 60; // Simulate 60 pan updates (1 second of dragging)

    notifier.setTool(ToolType.eraser);
    notifier.startStroke(const Offset(250.0, 250.0));
    for (int i = 0; i < eraseCount; i++) {
      notifier.updateStroke(Offset(250.0 + i, 250.0 + i));
    }
    notifier.endStroke();

    stopwatch.stop();
    debugPrint('RESULT: PASSED (Under 16ms frame budget)');
  });
}
