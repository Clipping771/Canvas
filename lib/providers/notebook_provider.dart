import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';
import '../models/notebook.dart';
import '../models/page.dart';
import '../models/stroke.dart';
import '../models/tool_type.dart';
import '../services/storage_service.dart';
import '../services/trivia_service.dart';

class NotebookNotifier extends Notifier<List<Notebook>> {
  @override
  List<Notebook> build() {
    return StorageService.loadNotebooks();
  }

  void save() {
    StorageService.saveNotebooks(state);
  }

  void addNotebook(String title) {
    final newNotebook = Notebook(
      id: const Uuid().v4(),
      title: title,
      pages: [],
    );
    state = [...state, newNotebook];
    save();
  }

  void renameNotebook(String id, String newTitle) {
    state = state.map((n) {
      if (n.id == id) {
        n.title = newTitle;
      }
      return n;
    }).toList();
    save();
  }

  void deleteNotebook(String id) {
    state = state.where((n) => n.id != id).toList();
    save();
  }

  Future<void> addPage(String notebookId) async {
    final triviaText = await TriviaService.getDailySurprise();
    final triviaStroke = Stroke(
      points: [const Offset(50100, 50200)],
      color: const Color(0xFF4A90E2),
      size: 40.0,
      toolType: ToolType.pen,
      text: triviaText,
    );
    
    final newPage = NotePage(id: const Uuid().v4(), strokes: [triviaStroke]);

    state = state.map((n) {
      if (n.id == notebookId) {
        return Notebook(id: n.id, title: n.title, pages: [...n.pages, newPage]);
      }
      return n;
    }).toList();
    save();
  }

  void deletePage(String notebookId, String pageId) {
    state = state.map((n) {
      if (n.id == notebookId) {
        return Notebook(
          id: n.id,
          title: n.title,
          pages: n.pages.where((p) => p.id != pageId).toList(),
        );
      }
      return n;
    }).toList();
    save();
  }

  void updatePage(String notebookId, NotePage updatedPage) {
    state = state.map((n) {
      if (n.id == notebookId) {
        final newPages = n.pages.map((p) {
          if (p.id == updatedPage.id) return updatedPage;
          return p;
        }).toList();
        return Notebook(id: n.id, title: n.title, pages: newPages);
      }
      return n;
    }).toList();
    save();
  }

  void renamePage(String notebookId, String pageId, String newTitle) {
    state = state.map((n) {
      if (n.id == notebookId) {
        final newPages = n.pages.map((p) {
          if (p.id == pageId) {
            p.title = newTitle;
          }
          return p;
        }).toList();
        return Notebook(id: n.id, title: n.title, pages: newPages);
      }
      return n;
    }).toList();
    save();
  }

  void togglePageStar(String notebookId, String pageId) {
    state = state.map((n) {
      if (n.id == notebookId) {
        final newPages = n.pages.map((p) {
          if (p.id == pageId) {
            p.isStarred = !p.isStarred;
          }
          return p;
        }).toList();
        return Notebook(id: n.id, title: n.title, pages: newPages);
      }
      return n;
    }).toList();
    save();
  }
}

final notebookProvider = NotifierProvider<NotebookNotifier, List<Notebook>>(
  NotebookNotifier.new,
);
