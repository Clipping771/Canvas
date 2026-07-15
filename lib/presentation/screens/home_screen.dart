import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/canvas_provider.dart';
import 'package:vinci_board/presentation/screens/canvas_screen.dart';
import 'package:vinci_board/core/models/app_canvas.dart';
import 'package:vinci_board/presentation/screens/settings_screen.dart';
import 'package:vinci_board/presentation/providers/gamification_provider.dart';
import 'package:vinci_board/presentation/widgets/gamification_dialog.dart';
import 'package:vinci_board/core/theme/da_vinci_theme.dart';
import 'package:vinci_board/presentation/screens/admin/admin_dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _currentFilter = 'Recent';
  List<String> get _filters => ['Recent', 'Starred', 'All'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
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

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Canvases?'),
        content: const Text(
          'Are you sure you want to delete all canvases? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(canvasProvider.notifier).deleteAllCanvases();
              Navigator.pop(context);
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gamification = ref.watch(gamificationProvider);
    if (!gamification.isLoaded) {
      Future.microtask(() => ref.read(gamificationProvider.notifier).init());
    }

    final canvases = ref.watch(canvasProvider);

    // Filter and sort canvases
    final List<AppCanvas> allPages = canvases.where((c) {
      if (_currentFilter == 'Starred' && !c.isStarred) return false;
      if (_searchQuery.isNotEmpty) {
        if (!c.title.toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort by date (descending)
    allPages.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final gState = ref.watch(gamificationProvider);
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 8.0,
                      top: 4.0,
                      bottom: 4.0,
                    ),
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      ),
                      label: Text(
                        'Lvl ${gState.level} ${gState.xp} XP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                  child: const Icon(
                    CupertinoIcons.settings,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 16, top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${allPages.length} canvas${allPages.length != 1 ? 'es' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search canvases and volumes',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildFilterBar()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  if (allPages.isNotEmpty) ...[
                    Expanded(
                      flex: 5,
                      child: _buildFeaturedCard(allPages.first),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(flex: 3, child: _buildNewVolumeCard(canvases)),
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
                final gridNotes = allPages.isNotEmpty
                    ? allPages.sublist(1)
                    : allPages;

                if (index < gridNotes.length) {
                  final item = gridNotes[index];
                  return _buildNoteCard(item);
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

  Widget _buildFeaturedCard(AppCanvas page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CanvasScreen(canvasId: page.id)),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF094184), // Solid deep blue
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF094184).withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Curvy wavy layers on the right side
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: PremiumCardWavesPainter(),
                ),
              ),
            ),
            // Text content on top
            Padding(
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNewVolumeCard(List<dynamic> canvases) {
    return GestureDetector(
      onTap: () async {
        await ref
            .read(canvasProvider.notifier)
            .addCanvas(title: 'Untitled Canvas');

        final newCanvas = ref.read(canvasProvider).last;

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CanvasScreen(canvasId: newCanvas.id),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color.lerp(
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.35),
                  _controller.value,
                )!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentLight,
                      AppColors.primary.withValues(alpha: 0.08),
                    ],
                  ),
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
                'New canvas',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
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
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: _confirmDeleteAll,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Delete All',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(AppCanvas page) {
    return _ScaleOnPress(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CanvasScreen(canvasId: page.id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.brush,
                    color: AppColors.primary.withValues(alpha: 0.6),
                    size: 24,
                  ),
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
          CustomPaint(painter: _DashedRectPainter(color: Colors.grey.shade400)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.sparkles,
                  color: Colors.grey.shade500,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  'More here soon',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 🌤️';
    if (hour < 21) return 'Good evening 🌅';
    return 'Good night 🌙';
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
        result.addPath(metric.extractPath(dist, dist + dashWidth), Offset.zero);
        dist += dashWidth + dashSpace;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A premium micro-interaction widget that scales down slightly on press for a tactile feel.
class _ScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleOnPress({required this.child, required this.onTap});

  @override
  State<_ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<_ScaleOnPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class PremiumCardWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Layer 1: Medium blue wave
    final p1 = Paint()
      ..color = const Color(0xFF3E75BA)
      ..style = PaintingStyle.fill;
    final path1 = Path();
    path1.moveTo(w * 0.58, 0);
    path1.cubicTo(w * 0.54, h * 0.15, w * 0.54, h * 0.25, w * 0.57, h * 0.35); // first crest (left)
    path1.cubicTo(w * 0.61, h * 0.45, w * 0.52, h * 0.60, w * 0.53, h * 0.75); // second crest (left)
    path1.cubicTo(w * 0.54, h * 0.85, w * 0.62, h * 0.90, w * 0.58, h);
    path1.lineTo(w, h);
    path1.lineTo(w, 0);
    path1.close();
    canvas.drawPath(path1, p1);

    // Layer 2: Light blue wave
    final p2 = Paint()
      ..color = const Color(0xFF7FAEE3)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(w * 0.65, 0);
    path2.cubicTo(w * 0.61, h * 0.15, w * 0.61, h * 0.25, w * 0.64, h * 0.35);
    path2.cubicTo(w * 0.68, h * 0.45, w * 0.59, h * 0.60, w * 0.60, h * 0.75);
    path2.cubicTo(w * 0.61, h * 0.85, w * 0.69, h * 0.90, w * 0.65, h);
    path2.lineTo(w, h);
    path2.lineTo(w, 0);
    path2.close();
    canvas.drawPath(path2, p2);

    // Layer 3: Very light blue wave
    final p3 = Paint()
      ..color = const Color(0xFFBDD7F5)
      ..style = PaintingStyle.fill;
    final path3 = Path();
    path3.moveTo(w * 0.73, 0);
    path3.cubicTo(w * 0.69, h * 0.15, w * 0.69, h * 0.25, w * 0.72, h * 0.35);
    path3.cubicTo(w * 0.76, h * 0.45, w * 0.67, h * 0.60, w * 0.68, h * 0.75);
    path3.cubicTo(w * 0.69, h * 0.85, w * 0.77, h * 0.90, w * 0.73, h);
    path3.lineTo(w, h);
    path3.lineTo(w, 0);
    path3.close();
    canvas.drawPath(path3, p3);

    // Layer 4: Light off-white area
    final p4 = Paint()
      ..color = const Color(0xFFF1F6FE)
      ..style = PaintingStyle.fill;
    final path4 = Path();
    path4.moveTo(w * 0.81, 0);
    path4.cubicTo(w * 0.77, h * 0.15, w * 0.77, h * 0.25, w * 0.80, h * 0.35);
    path4.cubicTo(w * 0.84, h * 0.45, w * 0.75, h * 0.60, w * 0.76, h * 0.75);
    path4.cubicTo(w * 0.77, h * 0.85, w * 0.85, h * 0.90, w * 0.81, h);
    path4.lineTo(w, h);
    path4.lineTo(w, 0);
    path4.close();
    canvas.drawPath(path4, p4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
