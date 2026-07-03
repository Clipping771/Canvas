import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notebook_provider.dart';
import 'canvas_screen.dart';
import '../models/page.dart';
import 'settings_screen.dart';
import '../providers/gamification_provider.dart';
import '../widgets/gamification_dialog.dart';
import '../core/theme/da_vinci_theme.dart';
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
    final gamification = ref.watch(gamificationProvider);
    if (!gamification.isLoaded) {
      Future.microtask(() => ref.read(gamificationProvider.notifier).init());
    }

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
                AppColors.background,
                AppColors.backgroundAlt,
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
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final gState = ref.watch(gamificationProvider);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                    child: ActionChip(
                      avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
                      label: Text('Lvl ${gState.level} (${gState.xp} XP)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.surface.withOpacity(0.8),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const GamificationDialog(),
                        );
                      },
                    ),
                  );
                },
              ),
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
                  color: AppColors.surface,
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
                childAspectRatio: 0.72,
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
        
        if (!mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) => 
                CanvasScreen(notebookId: defaultNotebook.id, pageId: newPage.id),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryDark.withOpacity(0.4), width: 2, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.add, 
                color: AppColors.primaryDark, 
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'New Volume',
                style: TextStyle(
                  color: AppColors.primaryDark,
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
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.shade900.withOpacity(isSelected ? 0.2 : 0.05),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? AppColors.surface : AppColors.textSecondary,
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
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) => 
                CanvasScreen(notebookId: notebookId, pageId: page.id),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: DaVinciTheme.warmShadow,
          border: const Border(
            right: BorderSide(color: AppColors.background, width: 4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 14, 
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primaryDark.withOpacity(0.7),
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ), // Book spine
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            page.strokes.isNotEmpty ? CupertinoIcons.book : CupertinoIcons.book_circle,
                            color: AppColors.accent.withOpacity(0.5),
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.title,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${page.dateCreated.day} ${_getMonth(page.dateCreated.month)}',
                            style: TextStyle(
                              color: AppColors.accent.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    color: AppColors.primaryDark.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    page.isStarred
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    color: page.isStarred
                        ? AppColors.accent
                        : AppColors.accent.withOpacity(0.3),
                    size: 18,
                  ),
                ),
              ),
            ),
                ],
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
