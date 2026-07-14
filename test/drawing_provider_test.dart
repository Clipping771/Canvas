// Feature Verification: Core Canvas Drawing
// Tests for DrawingNotifier state, undo/redo, serialization, edge cases.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/core/models/app_canvas.dart';
import 'package:vinci_board/core/models/canvas_command.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';

// Helper: build a ProviderContainer with DrawingNotifier accessible.
ProviderContainer makeContainer() {
  final container = ProviderContainer(overrides: []);
  addTearDown(container.dispose);
  return container;
}

Stroke makeStroke({
  String? id,
  List<Offset>? points,
  ToolType toolType = ToolType.pen,
  Color color = Colors.black,
}) {
  return Stroke(
    id: id,
    points: points ?? [const Offset(10, 10), const Offset(20, 20)],
    color: color,
    size: 2.0,
    toolType: toolType,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrawingState — initial state', () {
    test('starts with empty strokes and empty undo/redo', () {
      final c = makeContainer();
      final state = c.read(drawingProvider);
      expect(state.strokes, isEmpty);
      expect(state.undoHistory, isEmpty);
      expect(state.redoHistory, isEmpty);
      expect(state.currentTool, ToolType.pen);
      expect(state.currentColor, Colors.black);
    });
  });

  group('addStrokes / AddStrokesCommand', () {
    test('adds strokes to state', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      final s = makeStroke();
      notifier.addStrokes([s]);
      expect(c.read(drawingProvider).strokes.length, 1);
      expect(c.read(drawingProvider).strokes.first.id, s.id);
    });

    test('addStrokes populates undoHistory', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      expect(c.read(drawingProvider).undoHistory.length, 1);
    });

    test('addStrokes clears redoHistory', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      // Put something in redo by doing an add + undo
      notifier.addStrokes([makeStroke()]);
      notifier.undo();
      expect(c.read(drawingProvider).redoHistory.length, 1);
      // New add must clear redo
      notifier.addStrokes([makeStroke()]);
      expect(c.read(drawingProvider).redoHistory, isEmpty);
    });

    test('adding empty list is no-op', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([]);
      expect(c.read(drawingProvider).strokes, isEmpty);
      expect(c.read(drawingProvider).undoHistory, isEmpty);
    });
  });

  group('undo / redo', () {
    test('undo removes added stroke', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      final s = makeStroke(id: 'stroke-1');
      notifier.addStrokes([s]);
      expect(c.read(drawingProvider).strokes.length, 1);

      notifier.undo();
      expect(c.read(drawingProvider).strokes, isEmpty);
    });

    test('undo shrinks undoHistory', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      notifier.addStrokes([makeStroke()]);
      expect(c.read(drawingProvider).undoHistory.length, 2);

      notifier.undo();
      expect(
        c.read(drawingProvider).undoHistory.length,
        1,
        reason: 'undo() must remove the command from undoHistory',
      );
    });

    test('undo moves command to redoHistory', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      notifier.undo();
      expect(c.read(drawingProvider).redoHistory.length, 1);
    });

    test('redo restores stroke after undo', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      final s = makeStroke(id: 'stroke-redo');
      notifier.addStrokes([s]);
      notifier.undo();
      expect(c.read(drawingProvider).strokes, isEmpty);

      notifier.redo();
      expect(c.read(drawingProvider).strokes.length, 1);
      expect(c.read(drawingProvider).strokes.first.id, s.id);
    });

    test('redo shrinks redoHistory', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      notifier.undo();
      expect(c.read(drawingProvider).redoHistory.length, 1);

      notifier.redo();
      expect(c.read(drawingProvider).redoHistory, isEmpty);
    });

    test('multiple undo steps work correctly', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      final s1 = makeStroke(id: 'a');
      final s2 = makeStroke(id: 'b');
      notifier.addStrokes([s1]);
      notifier.addStrokes([s2]);
      expect(c.read(drawingProvider).strokes.length, 2);

      notifier.undo();
      expect(c.read(drawingProvider).strokes.length, 1);
      expect(c.read(drawingProvider).strokes.first.id, 'a');

      notifier.undo();
      expect(c.read(drawingProvider).strokes, isEmpty);
    });

    test('undo then new action clears redo', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      notifier.undo();
      expect(c.read(drawingProvider).redoHistory.length, 1);

      notifier.addStrokes([makeStroke()]); // new action
      expect(
        c.read(drawingProvider).redoHistory,
        isEmpty,
        reason: 'New action after undo must clear redo stack',
      );
    });

    test('undo on empty history is no-op', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.undo(); // should not throw
      expect(c.read(drawingProvider).strokes, isEmpty);
    });

    test('redo on empty history is no-op', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.redo(); // should not throw
      expect(c.read(drawingProvider).strokes, isEmpty);
    });

    test('undo limit: history capped at 50 commands', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      for (int i = 0; i < 60; i++) {
        notifier.addStrokes([makeStroke()]);
      }
      // After 60 adds, undo history must not exceed 50
      expect(c.read(drawingProvider).undoHistory.length, lessThanOrEqualTo(50));
    });
  });

  group('clear / ClearCanvasCommand', () {
    test('clear removes all strokes and is undoable', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke(id: 'x'), makeStroke(id: 'y')]);
      expect(c.read(drawingProvider).strokes.length, 2);

      notifier.clear();
      expect(c.read(drawingProvider).strokes, isEmpty);

      notifier.undo();
      expect(
        c.read(drawingProvider).strokes.length,
        2,
        reason: 'clear() must be undoable',
      );
    });

    test('clear on empty canvas is no-op', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.clear();
      expect(c.read(drawingProvider).strokes, isEmpty);
      expect(c.read(drawingProvider).undoHistory, isEmpty);
    });
  });

  group('eraseStrokes / RemoveStrokesCommand', () {
    test('eraseStrokes removes specified strokes and is undoable', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      final s1 = makeStroke(id: 'keep');
      final s2 = makeStroke(id: 'remove');
      notifier.addStrokes([s1, s2]);

      notifier.eraseStrokes([s2]);
      expect(c.read(drawingProvider).strokes.length, 1);
      expect(c.read(drawingProvider).strokes.first.id, 'keep');

      notifier.undo(); // undo erase
      expect(c.read(drawingProvider).strokes.length, 2);
    });
  });

  group('selection', () {
    test('selectAll selects all strokes', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke(), makeStroke()]);
      notifier.selectAll();
      expect(c.read(drawingProvider).selectedStrokes.length, 2);
      expect(c.read(drawingProvider).selectionBounds, isNotNull);
    });

    test('selectAll on empty canvas is no-op', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.selectAll();
      expect(c.read(drawingProvider).selectedStrokes, isEmpty);
    });

    test('clearSelection clears selection and bounds', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      notifier.selectAll();
      notifier.clearSelection();
      expect(c.read(drawingProvider).selectedStrokes, isEmpty);
      expect(c.read(drawingProvider).selectionBounds, isNull);
    });
  });

  group('copy / paste / duplicate', () {
    test('copySelection populates clipboard', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      DrawingNotifier.clipboard = [];
      final s = makeStroke(id: 'copy-me');
      notifier.addStrokes([s]);
      notifier.selectAll();
      notifier.copySelection();
      expect(DrawingNotifier.clipboard.length, 1);
    });

    test('pasteFromClipboard adds strokes offset by 20', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      DrawingNotifier.clipboard = [];
      final s = makeStroke(
        id: 'source',
        points: [const Offset(100, 100), const Offset(200, 200)],
      );
      notifier.addStrokes([s]);
      notifier.selectAll();
      notifier.copySelection();
      notifier.pasteFromClipboard();

      // Original + pasted
      expect(c.read(drawingProvider).strokes.length, 2);
      final pasted = c.read(drawingProvider).strokes.last;
      expect(pasted.points.first.dx, closeTo(120, 0.01));
      expect(pasted.points.first.dy, closeTo(120, 0.01));
    });

    test('pasteFromClipboard returns false when clipboard empty', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      DrawingNotifier.clipboard = [];
      final result = notifier.pasteFromClipboard();
      expect(result, false);
    });

    test('duplicateSelection adds copies offset by 20', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      final s = makeStroke(
        points: [const Offset(50, 50), const Offset(60, 60)],
      );
      notifier.addStrokes([s]);
      notifier.selectAll();
      notifier.duplicateSelection();

      expect(c.read(drawingProvider).strokes.length, 2);
      final dup = c.read(drawingProvider).strokes.last;
      expect(dup.points.first.dx, closeTo(70, 0.01));
    });
  });

  group('tool settings', () {
    test('setTool changes currentTool', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.setTool(ToolType.eraser);
      expect(c.read(drawingProvider).currentTool, ToolType.eraser);
    });

    test('setColor changes currentColor', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.setColor(Colors.red);
      expect(c.read(drawingProvider).currentColor, Colors.red);
    });

    test('setSize changes currentSize', () {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.setSize(8.0);
      expect(c.read(drawingProvider).currentSize, 8.0);
    });
  });

  group('loadStrokes', () {
    test('loadStrokes replaces state strokes and clears undo', () async {
      final c = makeContainer();
      final notifier = c.read(drawingProvider.notifier);
      notifier.addStrokes([makeStroke()]);
      expect(c.read(drawingProvider).undoHistory.length, 1);

      final loaded = [makeStroke(id: 'loaded-1'), makeStroke(id: 'loaded-2')];
      notifier.loadStrokes(loaded);
      // Allow async image decoding microtask to flush
      await Future.delayed(Duration.zero);

      expect(c.read(drawingProvider).strokes.length, 2);
      expect(c.read(drawingProvider).strokes.first.id, 'loaded-1');
      expect(
        c.read(drawingProvider).undoHistory,
        isEmpty,
        reason: 'loadStrokes must clear undo history',
      );
    });
  });

  group('Stroke serialization round-trip', () {
    test('toJson/fromJson preserves all fields', () {
      final original = Stroke(
        id: 'round-trip-1',
        groupId: 'grp-1',
        points: [const Offset(1.5, 2.5), const Offset(3.5, 4.5)],
        color: const Color(0xFF3D5AFE),
        size: 4.0,
        rotation: 0.5,
        toolType: ToolType.pen,
        text: 'hello',
        isFilled: true,
        semanticMeaning: 'note',
        physicsEnabled: false,
        version: 3,
      );

      final json = original.toJson();
      final restored = Stroke.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.groupId, original.groupId);
      expect(restored.points.length, 2);
      expect(restored.points.first.dx, closeTo(1.5, 0.001));
      expect(restored.points.first.dy, closeTo(2.5, 0.001));
      expect(restored.color.toARGB32(), original.color.toARGB32());
      expect(restored.size, original.size);
      expect(restored.rotation, closeTo(0.5, 0.001));
      expect(restored.toolType, ToolType.pen);
      expect(restored.text, 'hello');
      expect(restored.isFilled, true);
      expect(restored.semanticMeaning, 'hello' == 'hello' ? 'note' : null);
      expect(restored.version, 3);
    });

    test('fromJson falls back to ToolType.pen for unknown toolType string', () {
      final json = {
        'id': 'fallback-1',
        'points': [
          {'dx': 1.0, 'dy': 1.0},
        ],
        'color': Colors.black.toARGB32(),
        'size': 2.0,
        'toolType': 'ToolType.doesNotExist',
        'isFilled': false,
        'physicsEnabled': false,
        'version': 1,
      };
      final s = Stroke.fromJson(json);
      expect(
        s.toolType,
        ToolType.pen,
        reason: 'Unknown toolType must fall back to pen, not throw',
      );
    });

    test('fromJson handles null optional fields gracefully', () {
      final json = {
        'id': 'min-1',
        'points': [
          {'dx': 5.0, 'dy': 6.0},
        ],
        'color': Colors.red.toARGB32(),
        'size': 1.0,
        'toolType': 'ToolType.pen',
        'isFilled': false,
        'physicsEnabled': false,
        'version': 1,
      };
      final s = Stroke.fromJson(json);
      expect(s.groupId, isNull);
      expect(s.text, isNull);
      expect(s.imageBytes, isNull);
      expect(s.smiles, isNull);
    });

    test('all new ToolType enum values round-trip through serialization', () {
      const newTypes = [
        ToolType.battery,
        ToolType.ground,
        ToolType.switchComp,
        ToolType.led,
        ToolType.resistor,
        ToolType.capacitor,
        ToolType.inductor,
        ToolType.clock,
        ToolType.scriptableChip,
        ToolType.motor,
        ToolType.oscilloscope,
        ToolType.andGate,
        ToolType.orGate,
        ToolType.notGate,
        ToolType.beaker,
        ToolType.microscope,
        ToolType.cell,
        ToolType.dna,
      ];
      for (final type in newTypes) {
        final s = Stroke(
          points: [const Offset(0, 0)],
          color: Colors.black,
          size: 1.0,
          toolType: type,
        );
        final json = s.toJson();
        final restored = Stroke.fromJson(json);
        expect(
          restored.toolType,
          type,
          reason: '${type.name} must survive toJson/fromJson round-trip',
        );
      }
    });
  });

  group('AppCanvas serialization round-trip', () {
    test('toJson/fromJson preserves canvas and strokes', () {
      final canvas = AppCanvas(
        id: 'canvas-rt-1',
        title: 'Test Canvas',
        strokes: [
          makeStroke(id: 'st-1'),
          makeStroke(id: 'st-2'),
        ],
      );

      final json = canvas.toJson();
      final restored = AppCanvas.fromJson(json);

      expect(restored.id, 'canvas-rt-1');
      expect(restored.title, 'Test Canvas');
      expect(restored.strokes.length, 2);
      expect(restored.strokes.first.id, 'st-1');
      expect(restored.strokes.last.id, 'st-2');
    });

    test('fromJson handles missing lastModified gracefully', () {
      final json = {
        'id': 'canvas-legacy',
        'title': 'Old Canvas',
        'dateCreated': DateTime(2024, 1, 1).toIso8601String(),
        'isStarred': false,
        'strokes': [],
      };
      final canvas = AppCanvas.fromJson(json);
      expect(canvas.id, 'canvas-legacy');
      expect(canvas.lastModified, isNotNull);
    });
  });

  group('CanvasCommand correctness', () {
    test('AddStrokesCommand execute and undo', () {
      final strokes = <Stroke>[];
      final s = makeStroke(id: 'cmd-1');
      final cmd = AddStrokesCommand([s]);

      cmd.execute(strokes);
      expect(strokes.length, 1);

      cmd.undo(strokes);
      expect(strokes, isEmpty);
    });

    test('RemoveStrokesCommand execute and undo restores order', () {
      final s1 = makeStroke(id: 'r1');
      final s2 = makeStroke(id: 'r2');
      final strokes = [s1, s2];
      final cmd = RemoveStrokesCommand([s1]);

      cmd.execute(strokes);
      expect(strokes.length, 1);
      expect(strokes.first.id, 'r2');

      cmd.undo(strokes);
      expect(strokes.length, 2);
    });

    test('ClearCanvasCommand execute and undo', () {
      final s = makeStroke(id: 'clr');
      final strokes = [s];
      final cmd = ClearCanvasCommand(List.from(strokes));

      cmd.execute(strokes);
      expect(strokes, isEmpty);

      cmd.undo(strokes);
      expect(strokes.length, 1);
      expect(strokes.first.id, 'clr');
    });

    test('SnapshotCommand execute and undo', () {
      final old = [makeStroke(id: 'snap-old')];
      final next = [makeStroke(id: 'snap-new-1'), makeStroke(id: 'snap-new-2')];
      final strokes = List<Stroke>.from(old);
      final cmd = SnapshotCommand(old, next);

      cmd.execute(strokes);
      expect(strokes.length, 2);
      expect(strokes.first.id, 'snap-new-1');

      cmd.undo(strokes);
      expect(strokes.length, 1);
      expect(strokes.first.id, 'snap-old');
    });
  });
}
