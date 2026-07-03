import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/da_vinci_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _strokeRevealAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _strokeRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeInOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeInOut),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationCompleted = true;
        });
        // Auto-navigate after a brief delay
        Future.delayed(const Duration(milliseconds: 800), _navigateToHome);
      }
    });

    _controller.forward();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Allow tapping to skip after a short delay
          if (_controller.value > 0.2) {
            _navigateToHome();
          }
        },
        child: Stack(
          children: [
            // Sfumato / Radial Shading layer (fades in)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryDark.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Sketch Reveal Layer
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: AnimatedBuilder(
                  animation: _strokeRevealAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SketchRevealPainter(
                        revealFraction: _strokeRevealAnimation.value,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Wordmark and prompt layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: FadeTransition(
                opacity: _textFadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Vinci Board',
                      style: GoogleFonts.cinzel(
                        color: AppColors.textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _animationCompleted ? 0.6 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        'Tap to Enter the Studio',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SketchRevealPainter extends CustomPainter {
  final double revealFraction;
  final Color color;

  SketchRevealPainter({required this.revealFraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (revealFraction == 0.0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // A stylized Vitruvian/Infinity knot or abstract signature path
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.cubicTo(
      size.width * 0.2, size.height * 0.2,
      size.width * 0.8, size.height * 0.2,
      size.width * 0.8, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.8, size.height * 0.8,
      size.width * 0.2, size.height * 0.8,
      size.width * 0.2, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.2, size.height * 0.3,
      size.width * 0.5, size.height * 0.3,
      size.width * 0.5, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.5, size.height * 0.7,
      size.width * 0.8, size.height * 0.7,
      size.width * 0.8, size.height * 0.5,
    );

    // Extract the portion of the path based on revealFraction
    ui.PathMetrics pathMetrics = path.computeMetrics();
    Path extractedPath = Path();

    for (ui.PathMetric metric in pathMetrics) {
      final extractLength = metric.length * revealFraction;
      extractedPath.addPath(metric.extractPath(0.0, extractLength), Offset.zero);

      // Draw the "ink bleed" micro-effect at the leading edge
      if (revealFraction < 1.0) {
        final tangent = metric.getTangentForOffset(extractLength);
        if (tangent != null) {
          final dotPaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(tangent.position, 2.5, dotPaint);
        }
      }
    }

    canvas.drawPath(extractedPath, paint);
  }

  @override
  bool shouldRepaint(covariant SketchRevealPainter oldDelegate) {
    return oldDelegate.revealFraction != revealFraction;
  }
}
