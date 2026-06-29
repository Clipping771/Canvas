import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notebook_provider.dart';
import 'canvas_screen.dart';

class NotebookScreen extends ConsumerWidget {
  final String notebookId;
  const NotebookScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebookProvider);
    final notebook = notebooks.firstWhere(
      (n) => n.id == notebookId,
      orElse: () => notebooks.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(notebook.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: notebook.pages.isEmpty
          ? const Center(child: Text('No pages yet. Tap + to create one.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: notebook.pages.length,
              itemBuilder: (context, index) {
                final page = notebook.pages[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CanvasScreen(
                          notebookId: notebook.id,
                          pageId: page.id,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.white,
                    elevation: 2,
                    child: Stack(
                      children: [
                        Center(child: Text('Page ${index + 1}')),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                ref
                                    .read(notebookProvider.notifier)
                                    .deletePage(notebook.id, page.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(notebookProvider.notifier).addPage(notebook.id);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
