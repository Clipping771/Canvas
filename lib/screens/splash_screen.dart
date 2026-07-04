import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Colours — aged parchment palette
// ─────────────────────────────────────────────────────────────
const _kParchment   = Color(0xFFF5E6C8);
const _kInk         = Color(0xFF2C1810);
const _kInkMid      = Color(0xFF5C3A1E);
const _kInkLight    = Color(0xFF8B6345);
const _kCandle      = Color(0xFFFFD070);
const _kGoldTitle   = Color(0xFF8B6914);

// ─────────────────────────────────────────────────────────────
//  Da Vinci face stroke data
//  Every entry = one "brush stroke" drawn in sequence.
//  Points are in a 200×260 viewport (normalised 0..1 later).
//  Structure: { 'name', 'points': List<Offset>, 'width' }
// ─────────────────────────────────────────────────────────────
List<_StrokeData> _buildFaceStrokes() {
  // Helper: cubic bezier to point list
  List<Offset> bez(Offset p0, Offset p1, Offset p2, Offset p3,
      {int steps = 28}) {
    final pts = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final mt = 1 - t;
      pts.add(Offset(
        mt * mt * mt * p0.dx +
            3 * mt * mt * t * p1.dx +
            3 * mt * t * t * p2.dx +
            t * t * t * p3.dx,
        mt * mt * mt * p0.dy +
            3 * mt * mt * t * p1.dy +
            3 * mt * t * t * p2.dy +
            t * t * t * p3.dy,
      ));
    }
    return pts;
  }

  // Helper: arc to points
  List<Offset> arc(Offset center, double rx, double ry, double startDeg,
      double endDeg,
      {int steps = 24}) {
    final pts = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final ang =
          (startDeg + (endDeg - startDeg) * i / steps) * math.pi / 180;
      pts.add(Offset(
          center.dx + rx * math.cos(ang), center.dy + ry * math.sin(ang)));
    }
    return pts;
  }

  // Helper: straight line with slight wobble
  List<Offset> line(Offset a, Offset b, {int steps = 12, double wobble = 0.8}) {
    final rng = math.Random(a.dx.toInt() ^ b.dy.toInt());
    final pts = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final w = wobble * math.sin(t * math.pi);
      pts.add(Offset(
        a.dx + (b.dx - a.dx) * t + (rng.nextDouble() - 0.5) * w,
        a.dy + (b.dy - a.dy) * t + (rng.nextDouble() - 0.5) * w,
      ));
    }
    return pts;
  }

  return [
    // ── Outer head silhouette ──────────────────────────────
    _StrokeData('head_left',
        bez(const Offset(95, 18), const Offset(44, 22),
            const Offset(28, 80), const Offset(34, 140),
            steps: 40),
        2.2),
    _StrokeData('head_jaw_left',
        bez(const Offset(34, 140), const Offset(36, 192),
            const Offset(62, 222), const Offset(100, 230),
            steps: 32),
        2.0),
    _StrokeData('head_jaw_right',
        bez(const Offset(100, 230), const Offset(138, 222),
            const Offset(162, 192), const Offset(164, 140),
            steps: 32),
        2.0),
    _StrokeData('head_right',
        bez(const Offset(164, 140), const Offset(170, 80),
            const Offset(154, 22), const Offset(105, 18),
            steps: 40),
        2.2),

    // ── Forehead / hairline ───────────────────────────────
    _StrokeData('hairline',
        bez(const Offset(52, 48), const Offset(78, 30),
            const Offset(122, 30), const Offset(148, 48),
            steps: 28),
        1.4),

    // ── Left eyebrow ──────────────────────────────────────
    _StrokeData('brow_left',
        bez(const Offset(52, 90), const Offset(62, 82),
            const Offset(76, 80), const Offset(88, 84),
            steps: 20),
        1.8),

    // ── Right eyebrow ─────────────────────────────────────
    _StrokeData('brow_right',
        bez(const Offset(112, 84), const Offset(124, 80),
            const Offset(138, 82), const Offset(148, 90),
            steps: 20),
        1.8),

    // ── Left eye ──────────────────────────────────────────
    _StrokeData('eye_left_top',
        bez(const Offset(52, 102), const Offset(62, 94),
            const Offset(76, 93), const Offset(88, 102),
            steps: 22),
        1.6),
    _StrokeData('eye_left_bot',
        bez(const Offset(52, 102), const Offset(62, 110),
            const Offset(76, 111), const Offset(88, 102),
            steps: 18),
        1.3),
    // Iris
    _StrokeData('iris_left',
        arc(const Offset(70, 102), 7, 5.5, 0, 360, steps: 24),
        1.2),
    // Pupil dot approximated as tiny circle
    _StrokeData('pupil_left',
        arc(const Offset(70, 102), 3, 2.5, 0, 360, steps: 16),
        2.5),

    // ── Right eye ─────────────────────────────────────────
    _StrokeData('eye_right_top',
        bez(const Offset(112, 102), const Offset(124, 93),
            const Offset(138, 94), const Offset(148, 102),
            steps: 22),
        1.6),
    _StrokeData('eye_right_bot',
        bez(const Offset(112, 102), const Offset(124, 111),
            const Offset(138, 110), const Offset(148, 102),
            steps: 18),
        1.3),
    _StrokeData('iris_right',
        arc(const Offset(130, 102), 7, 5.5, 0, 360, steps: 24),
        1.2),
    _StrokeData('pupil_right',
        arc(const Offset(130, 102), 3, 2.5, 0, 360, steps: 16),
        2.5),

    // ── Nose bridge ───────────────────────────────────────
    _StrokeData('nose_bridge',
        bez(const Offset(96, 98), const Offset(93, 120),
            const Offset(91, 138), const Offset(88, 150),
            steps: 20),
        1.3),

    // ── Nose tip / nostrils ───────────────────────────────
    _StrokeData('nose_tip',
        bez(const Offset(88, 150), const Offset(90, 158),
            const Offset(110, 158), const Offset(112, 150),
            steps: 18),
        1.5),
    _StrokeData('nostril_left',
        arc(const Offset(84, 153), 6, 4, 160, 340, steps: 14),
        1.2),
    _StrokeData('nostril_right',
        arc(const Offset(116, 153), 6, 4, 200, 380, steps: 14),
        1.2),

    // ── Mouth ─────────────────────────────────────────────
    _StrokeData('lip_top',
        bez(const Offset(78, 172), const Offset(90, 166),
            const Offset(110, 166), const Offset(122, 172),
            steps: 22),
        1.6),
    _StrokeData('lip_bot',
        bez(const Offset(78, 172), const Offset(88, 182),
            const Offset(112, 182), const Offset(122, 172),
            steps: 22),
        1.4),
    // Cupid's bow
    _StrokeData('cupid_bow',
        bez(const Offset(88, 168), const Offset(97, 164),
            const Offset(103, 164), const Offset(112, 168),
            steps: 14),
        1.1),

    // ── Cheekbones (light shading lines) ─────────────────
    _StrokeData('cheek_left_1',
        line(const Offset(40, 130), const Offset(60, 128), wobble: 1.2),
        0.8),
    _StrokeData('cheek_left_2',
        line(const Offset(38, 138), const Offset(56, 136), wobble: 1.2),
        0.8),
    _StrokeData('cheek_right_1',
        line(const Offset(140, 128), const Offset(160, 130), wobble: 1.2),
        0.8),
    _StrokeData('cheek_right_2',
        line(const Offset(144, 136), const Offset(162, 138), wobble: 1.2),
        0.8),

    // ── Beard / mustache ──────────────────────────────────
    _StrokeData('mustache_left',
        bez(const Offset(78, 174), const Offset(72, 178),
            const Offset(70, 185), const Offset(76, 190),
            steps: 16),
        1.4),
    _StrokeData('mustache_right',
        bez(const Offset(122, 174), const Offset(128, 178),
            const Offset(130, 185), const Offset(124, 190),
            steps: 16),
        1.4),
    _StrokeData('beard_center',
        bez(const Offset(92, 188), const Offset(96, 196),
            const Offset(104, 196), const Offset(108, 188),
            steps: 14),
        1.3),
    _StrokeData('beard_left_1',
        bez(const Offset(70, 192), const Offset(72, 210),
            const Offset(82, 222), const Offset(94, 224),
            steps: 18),
        1.2),
    _StrokeData('beard_left_2',
        bez(const Offset(66, 196), const Offset(68, 214),
            const Offset(78, 224), const Offset(90, 226),
            steps: 18),
        1.0),
    _StrokeData('beard_right_1',
        bez(const Offset(130, 192), const Offset(128, 210),
            const Offset(118, 222), const Offset(106, 224),
            steps: 18),
        1.2),
    _StrokeData('beard_right_2',
        bez(const Offset(134, 196), const Offset(132, 214),
            const Offset(122, 224), const Offset(110, 226),
            steps: 18),
        1.0),

    // ── Long hair flowing lines ───────────────────────────
    _StrokeData('hair_left_1',
        bez(const Offset(50, 42), const Offset(28, 80),
            const Offset(20, 130), const Offset(24, 180),
            steps: 36),
        1.1),
    _StrokeData('hair_left_2',
        bez(const Offset(46, 44), const Offset(22, 82),
            const Offset(14, 132), const Offset(18, 185),
            steps: 36),
        1.0),
    _StrokeData('hair_left_3',
        bez(const Offset(54, 40), const Offset(36, 76),
            const Offset(28, 126), const Offset(30, 175),
            steps: 36),
        0.9),
    _StrokeData('hair_right_1',
        bez(const Offset(150, 42), const Offset(172, 80),
            const Offset(180, 130), const Offset(176, 180),
            steps: 36),
        1.1),
    _StrokeData('hair_right_2',
        bez(const Offset(154, 44), const Offset(178, 82),
            const Offset(186, 132), const Offset(182, 185),
            steps: 36),
        1.0),
    _StrokeData('hair_right_3',
        bez(const Offset(146, 40), const Offset(164, 76),
            const Offset(172, 126), const Offset(170, 175),
            steps: 36),
        0.9),

    // ── Ear left ──────────────────────────────────────────
    _StrokeData('ear_left',
        arc(const Offset(30, 118), 8, 14, 270, 90, steps: 20),
        1.4),
    // ── Ear right ─────────────────────────────────────────
    _StrokeData('ear_right',
        arc(const Offset(170, 118), 8, 14, 90, 270, steps: 20),
        1.4),

    // ── Neck ──────────────────────────────────────────────
    _StrokeData('neck_left',
        line(const Offset(84, 228), const Offset(80, 260)),
        1.6),
    _StrokeData('neck_right',
        line(const Offset(116, 228), const Offset(120, 260)),
        1.6),
  ];
}

class _StrokeData {
  final String name;
  final List<Offset> points;
  final double width;
  const _StrokeData(this.name, this.points, this.width);
}

// ─────────────────────────────────────────────────────────────
//  Splash Screen Widget
// ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main drawing controller
  late AnimationController _drawCtrl;
  // Candle flicker controller (loops)
  late AnimationController _flickerCtrl;
  // Title fade controller
  late AnimationController _titleCtrl;
  // Glow pulse controller
  late AnimationController _glowCtrl;

  late Animation<double> _drawProgress;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _bgFade;

  final List<_StrokeData> _strokes = _buildFaceStrokes();
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();

    // Total draw time scales with stroke count
    final drawMs = 200 + _strokes.length * 72; // ~3.4s for full face

    _drawCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: drawMs),
    );

    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _drawProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _drawCtrl, curve: Curves.easeInOut),
    );

    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _drawCtrl, curve: const Interval(0, 0.12, curve: Curves.easeIn)),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleCtrl,
          curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleCtrl,
          curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    // Allow skip after first 15% drawn
    _drawCtrl.addListener(() {
      if (!_canSkip && _drawCtrl.value > 0.15) {
        setState(() => _canSkip = true);
      }
    });

    _drawCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _titleCtrl.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 900), _goHome);
        });
      }
    });

    _drawCtrl.forward();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 700),
    ));
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _flickerCtrl.dispose();
    _titleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kInk,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _canSkip ? _goHome : null,
        child: Stack(fit: StackFit.expand, children: [
          // ── Parchment background fades in ──────────────
          AnimatedBuilder(
            animation: _bgFade,
            builder: (_, __) => Container(
              color: Color.lerp(_kInk, _kParchment, _bgFade.value),
            ),
          ),

          // ── Candlelight vignette ───────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_flickerCtrl, _bgFade]),
            builder: (_, __) {
              final flicker = 0.82 + 0.18 * _flickerCtrl.value;
              final alpha = (_bgFade.value * 0.55 * flicker).clamp(0.0, 1.0);
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.72,
                    colors: [
                      _kCandle.withOpacity(alpha * 0.38),
                      _kParchment.withOpacity(0),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Dark vignette edges ────────────────────────
          AnimatedBuilder(
            animation: _bgFade,
            builder: (_, __) => IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      _kInk.withOpacity(_bgFade.value * 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Da Vinci face drawing ──────────────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_drawProgress, _glowCtrl]),
              builder: (_, __) => CustomPaint(
                size: Size(size.width * 0.58,
                    size.width * 0.58 * (260 / 200)),
                painter: _DaVinciFacePainter(
                  progress: _drawProgress.value,
                  strokes: _strokes,
                  glowPulse: _glowCtrl.value,
                ),
              ),
            ),
          ),

          // ── Title "Vinci Board" ────────────────────────
          Positioned(
            left: 0, right: 0,
            bottom: size.height * 0.11,
            child: AnimatedBuilder(
              animation: _titleFade,
              builder: (_, __) => Column(
                children: [
                  Opacity(
                    opacity: _titleFade.value,
                    child: Text(
                      'Vinci Board',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: _kGoldTitle,
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            color: _kCandle.withOpacity(0.5),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: _subtitleFade.value * (_canSkip ? 1 : 0),
                    child: Text(
                      'TAP TO ENTER THE STUDIO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kInkLight,
                        fontSize: 11,
                        letterSpacing: 3.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom Painter — draws the face stroke by stroke
// ─────────────────────────────────────────────────────────────
class _DaVinciFacePainter extends CustomPainter {
  final double progress; // 0..1 overall draw progress
  final List<_StrokeData> strokes;
  final double glowPulse; // 0..1 for subtle glow pulse on pen tip

  _DaVinciFacePainter({
    required this.progress,
    required this.strokes,
    required this.glowPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    // Scale from 200×260 design space → actual canvas size
    final scaleX = size.width / 200.0;
    final scaleY = size.height / 260.0;

    Offset sc(Offset p) => Offset(p.dx * scaleX, p.dy * scaleY);

    // How many strokes to draw (fractional)
    final totalStrokes = strokes.length;
    final strokesDone = progress * totalStrokes; // e.g. 12.7

    Offset? penTip;

    for (int i = 0; i < totalStrokes; i++) {
      if (i >= strokesDone) break;

      final stroke = strokes[i];
      final pts = stroke.points;
      if (pts.isEmpty) continue;

      // Fraction of THIS stroke that is drawn
      double strokeFrac;
      if (i < strokesDone - 1) {
        strokeFrac = 1.0; // fully drawn
      } else {
        strokeFrac = strokesDone - i; // partial 0..1
      }

      final drawCount = ((pts.length - 1) * strokeFrac).round().clamp(1, pts.length - 1);

      // ── Build path ─────────────────────────────────────
      final path = Path();
      path.moveTo(sc(pts[0]).dx, sc(pts[0]).dy);
      for (int j = 1; j <= drawCount; j++) {
        path.lineTo(sc(pts[j]).dx, sc(pts[j]).dy);
      }

      // ── Ink colour — darker core strokes, lighter hair ─
      final isHair = stroke.name.startsWith('hair');
      final isShade = stroke.name.startsWith('cheek');
      final isBeard = stroke.name.startsWith('beard') ||
          stroke.name.startsWith('mustache');

      Color inkColor;
      if (isShade) {
        inkColor = _kInkLight;
      } else if (isHair) {
        inkColor = _kInkMid;
      } else if (isBeard) {
        inkColor = _kInkMid;
      } else {
        inkColor = _kInk;
      }

      // ── Subtle sfumato glow under thick strokes ────────
      if (stroke.width >= 1.8) {
        final glowPaint = Paint()
          ..color = _kInkLight.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (stroke.width * scaleX + 4)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawPath(path, glowPaint);
      }

      // ── Main ink stroke ────────────────────────────────
      final paint = Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width * scaleX
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, paint);

      // Track pen tip position (last drawn point of last partial stroke)
      if (strokeFrac < 1.0) {
        penTip = sc(pts[drawCount]);
      }
    }

    // ── Pen tip glow ───────────────────────────────────────
    if (penTip != null && progress < 0.99) {
      final glow = 0.5 + 0.5 * glowPulse;

      // Outer halo
      canvas.drawCircle(
        penTip,
        7 * glow,
        Paint()
          ..color = _kCandle.withOpacity(0.25 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Inner bright dot
      canvas.drawCircle(
        penTip,
        2.2,
        Paint()..color = _kCandle.withOpacity(0.85 * glow),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DaVinciFacePainter old) =>
      old.progress != progress || old.glowPulse != glowPulse;
}
