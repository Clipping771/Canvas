import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notebook_provider.dart';
import 'canvas_screen.dart';
import '../models/page.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignment;
  late Animation<Alignment> _bottomAlignment;

  String _currentFilter = 'Recent';
  List<String> get _filters => ['Recent', 'Starred', 'All'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _topAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _bottomAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notebooks = ref.watch(notebookProvider);

    // Flatten all pages for the view
    final List<Map<String, dynamic>> allPages = [];
    for (var n in notebooks) {
      for (var p in n.pages) {
        if (_currentFilter == 'Starred' && !p.isStarred) continue;
        allPages.add({'notebookId': n.id, 'page': p});
      }
    }

    // Sort by date (descending)
    allPages.sort(
      (a, b) => (b['page'] as NotePage).dateCreated.compareTo(
        (a['page'] as NotePage).dateCreated,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignment.value,
              end: _bottomAlignment.value,
              colors: const [
                Color(0xFFFFEBF0), // Light pink
                Color(0xFFE3F2FD), // Light blue
              ],
            ),
          ),
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Explore',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: Color(0xFF1E1E1E),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.settings, size: 24, color: Colors.black54),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(CupertinoIcons.search, color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildFilterBar()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == 0) {
                  return _buildNewNoteCard(notebooks);
                }
                final item = allPages[index - 1];
                return _buildNoteCard(
                  item['page'] as NotePage,
                  item['notebookId'] as String,
                );
              }, childCount: allPages.length + 1),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildNewNoteCard(List<dynamic> notebooks) {
    return GestureDetector(
      onTap: () async {
        if (notebooks.isEmpty) {
          ref.read(notebookProvider.notifier).addNotebook('My Notebook');
        }
        final defaultNotebook = ref.read(notebookProvider).first;
        await ref.read(notebookProvider.notifier).addPage(defaultNotebook.id);
        
        final updatedNotebook = ref.read(notebookProvider).firstWhere((n) => n.id == defaultNotebook.id);
        final newPage = updatedNotebook.pages.last;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CanvasScreen(notebookId: defaultNotebook.id, pageId: newPage.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.3), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.add, 
                color: const Color(0xFF4A90E2).withOpacity(0.5), 
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'New Note',
                style: TextStyle(
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _currentFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _currentFilter = filter);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSelected ? 0.2 : 0.05),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoteCard(NotePage page, String notebookId) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CanvasScreen(notebookId: notebookId, pageId: page.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8), // Soft blue background
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: page.strokes.isNotEmpty
                            ? const Icon(
                                CupertinoIcons.scribble,
                                color: Color(0xFF4A90E2),
                                size: 36,
                              )
                            : const Text(
                                'Empty',
                                style: TextStyle(
                                  color: Color(0xFF4A90E2),
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          page.title,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${page.dateCreated.day} ${_getMonth(page.dateCreated.month)}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(notebookProvider.notifier)
                      .togglePageStar(notebookId, page.id);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    page.isStarred
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    color: page.isStarred
                        ? const Color(0xFFFFB800)
                        : Colors.grey[400],
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
