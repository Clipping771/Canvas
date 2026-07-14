import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';
import 'package:vinci_board/core/models/app_canvas.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/adapters/storage/storage_service.dart';
import 'package:vinci_board/engines/trivia/trivia_service.dart';
import 'package:vinci_board/adapters/storage/cloud_sync_service.dart';

class CanvasNotifier extends Notifier<List<AppCanvas>> {
  Timer? _syncDebouncer;

  @override
  List<AppCanvas> build() {
    ref.onDispose(() {
      _syncDebouncer?.cancel();
    });
    return StorageService.loadCanvases();
  }

  void _triggerDebouncedSync() {
    if (_syncDebouncer?.isActive ?? false) _syncDebouncer!.cancel();
    _syncDebouncer = Timer(const Duration(seconds: 2), () {
      CloudSyncService().syncDirtyCanvases();
    });
  }

  void _saveCanvasLocally(AppCanvas canvas) {
    // Fire and forget local granular save
    StorageService.saveCanvas(canvas);
    _triggerDebouncedSync();
  }

  Future<void> addCanvas({String title = 'Untitled Canvas'}) async {
    final triviaText = await TriviaService.getDailySurprise();
    final triviaStroke = Stroke(
      points: [const Offset(200, 200)], // Also fixed LOW #14 trivia position!
      color: const Color(0xFF4A90E2),
      size: 40.0,
      toolType: ToolType.text,
      text: triviaText,
    );

    final newCanvas = AppCanvas(
      id: const Uuid().v4(),
      title: title,
      strokes: [triviaStroke],
    );

    state = [...state, newCanvas];
    _saveCanvasLocally(newCanvas);
  }

  void deleteCanvas(String id) {
    state = state.where((c) => c.id != id).toList();
    StorageService.deleteCanvas(id);
    _triggerDebouncedSync();
  }

  void deleteAllCanvases() {
    for (var c in state) {
      StorageService.deleteCanvas(c.id);
    }
    state = [];
    _triggerDebouncedSync();
  }

  void updateCanvas(AppCanvas updatedCanvas) {
    state = state.map((c) {
      if (c.id == updatedCanvas.id) {
        return updatedCanvas;
      }
      return c;
    }).toList();
    _saveCanvasLocally(updatedCanvas);
  }

  void renameCanvas(String id, String newTitle) {
    AppCanvas? updated;
    state = state.map((c) {
      if (c.id == id) {
        updated = AppCanvas(
          id: c.id,
          title: newTitle,
          dateCreated: c.dateCreated,
          isStarred: c.isStarred,
          strokes: c.strokes,
        );
        return updated!;
      }
      return c;
    }).toList();
    if (updated != null) _saveCanvasLocally(updated!);
  }

  void toggleCanvasStar(String id) {
    AppCanvas? updated;
    state = state.map((c) {
      if (c.id == id) {
        updated = AppCanvas(
          id: c.id,
          title: c.title,
          dateCreated: c.dateCreated,
          isStarred: !c.isStarred,
          strokes: c.strokes,
        );
        return updated!;
      }
      return c;
    }).toList();
    if (updated != null) _saveCanvasLocally(updated!);
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, List<AppCanvas>>(
  CanvasNotifier.new,
);
