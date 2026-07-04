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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _currentFilter = 'Recent';
  List<String> get _filters => ['Recent', 'Starred', 'All'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        if (_searchQuery.isNotEmpty) {
          if (!p.title.toLowerCase().contains(_searchQuery) && !n.title.toLowerCase().contains(_searchQuery)) {
            continue;
          }
        }
        allPages.add({'notebookId': n.id, 'page': p});
      }
    }

    // Sort by date (descending)
    allPages.sort(
      (a, b) => (b['page'] as NotePage).dateCreated.compareTo(
        (a['page'] as NotePage).dateCreated,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${notebooks.length} volume${notebooks.length != 1 ? 's' : ''} • ${allPages.length} canvas${allPages.length != 1 ? 'es' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final gState = ref.watch(gamificationProvider);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                    child: ActionChip(
                      avatar: const Icon(Icons.star_border, color: Colors.amber, size: 18),
                      label: Text('Lvl ${gState.level} ${gState.xp} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.settings, size: 20, color: Colors.black54),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search canvases and volumes',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildFilterBar()),          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  if (allPages.isNotEmpty) ...[
                    Expanded(
                      flex: 5,
                      child: _buildFeaturedCard(allPages.first['page'], allPages.first['notebookId']),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    flex: 3,
                    child: _buildNewVolumeCard(notebooks),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                // If there are notes, the first note is featured, so skip index 0
                final gridNotes = allPages.isNotEmpty ? allPages.sublist(1) : allPages;
                
                if (index < gridNotes.length) {
                  final item = gridNotes[index];
                  return _buildNoteCard(item['page'], item['notebookId']);
                } else if (index == gridNotes.length) {
                  return _buildPlaceholderCard();
                }
                return null;
              }, childCount: (allPages.isNotEmpty ? allPages.length - 1 : 0) + 1),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(NotePage page, String notebookId) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CanvasScreen(notebookId: notebookId, pageId: page.id)),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const Spacer(),
            Text(
              page.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Last edited ${page.dateCreated.day} ${_getMonth(page.dateCreated.month)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewVolumeCard(List<dynamic> notebooks) {
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
          MaterialPageRoute(builder: (_) => CanvasScreen(notebookId: defaultNotebook.id, pageId: newPage.id)),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.add, 
                  color: AppColors.primary, 
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'New volume',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
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
          MaterialPageRoute(builder: (_) => CanvasScreen(notebookId: notebookId, pageId: page.id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.brush, color: AppColors.primary, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              page.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${page.dateCreated.day} ${_getMonth(page.dateCreated.month)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _DashedRectPainter(color: Colors.grey.shade400),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.sparkles, color: Colors.grey.shade500, size: 24),
                const SizedBox(height: 8),
                Text(
                  'More here soon',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 12.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final dashPath = _dashPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, double dashWidth, double dashSpace) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        result.addPath(
          metric.extractPath(dist, dist + dashWidth),
          Offset.zero,
        );
        dist += dashWidth + dashSpace;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
