// ignore_for_file: unused_element
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinci_board/presentation/screens/home_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vinci_board/presentation/screens/splash_face_data.dart';

// ─────────────────────────────────────────────────────────────
//  Colours — aged parchment palette
// ─────────────────────────────────────────────────────────────
const _kInk = Color(0xFF2C1810);
const _kInkMid = Color(0xFF5C3A1E);
const _kCandle = Color(0xFFFFD070);

// _buildFaceStrokes and _StrokeData have been moved to splash_face_data.dart
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

  final List<StrokeData> _strokes = buildDetailedDaVinciStrokes();
  bool _canSkip = false;
  int _lastStrokeFloor = -1;
  AudioPlayer? _popPlayer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !Platform.isWindows) {
      _popPlayer = AudioPlayer();
      _popPlayer!.setSource(AssetSource('pop.mp3')).catchError((_) {});
    }

    // Total draw time scales with stroke count
    final drawMs = 200 + _strokes.length * 55; // slower, smoother strokes

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

    _drawProgress = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _drawCtrl, curve: Curves.easeInOut));

    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawCtrl,
        curve: const Interval(0, 0.12, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _titleCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _titleCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    // Allow skip after first 15% drawn
    _drawCtrl.addListener(() {
      if (!_canSkip && _drawCtrl.value > 0.15) {
        setState(() => _canSkip = true);
      }

      if (_drawCtrl.isAnimating) {
        final totalStrokes = _strokes.length;
        final strokesDone = (_drawProgress.value * totalStrokes).floor();
        if (strokesDone > _lastStrokeFloor && strokesDone < totalStrokes) {
          _lastStrokeFloor = strokesDone;
        }
      }
    });

    _drawCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _popPlayer
            ?.seek(Duration.zero)
            .then((_) => _popPlayer?.resume())
            .catchError((_) {});
        _titleCtrl.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 900), _goHome);
        });
      }
    });

    // Start immediately, no need to wait for sound engine
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _drawCtrl.forward();
    });
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  void dispose() {
    _popPlayer?.dispose();
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Animated gradient background ──────────────
            AnimatedBuilder(
              animation: _bgFade,
              builder: (_, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color.lerp(
                            Colors.white,
                            Colors.blue.shade100,
                            _bgFade.value,
                          ) ??
                          Colors.white,
                    ],
                  ),
                ),
              ),
            ),

            // ── Candlelight vignette ───────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_flickerCtrl, _bgFade]),
              builder: (_, _) {
                final flicker = 0.82 + 0.18 * _flickerCtrl.value;
                final alpha = (_bgFade.value * 0.2 * flicker).clamp(0.0, 1.0);
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.72,
                      colors: [
                        Colors.white.withValues(alpha: alpha),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Dark vignette edges ────────────────────────
            AnimatedBuilder(
              animation: _bgFade,
              builder: (_, _) => IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        Colors.blue.shade900.withValues(
                          alpha: _bgFade.value * 0.15,
                        ),
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
                builder: (_, _) {
                  final double maxFaceWidth = math.min(
                    size.width * 0.65,
                    280.0,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 120.0,
                    ), // Keep away from text
                    child: CustomPaint(
                      size: Size(maxFaceWidth, maxFaceWidth * (260 / 200)),
                      painter: _DaVinciFacePainter(
                        progress: _drawProgress.value,
                        strokes: _strokes,
                        glowPulse: _glowCtrl.value,
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Title "Vinci Board" ────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.11,
              child: AnimatedBuilder(
                animation: _titleFade,
                builder: (_, _) => Column(
                  children: [
                    Opacity(
                      opacity: _titleFade.value,
                      child: Text(
                        'Vinci Board',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: Colors.blue.shade900,
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: Colors.blue.withValues(alpha: 0.15),
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
                          color: Colors.blue.shade700,
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom Painter — draws the face stroke by stroke
// ─────────────────────────────────────────────────────────────
class _DaVinciFacePainter extends CustomPainter {
  final double progress; // 0..1 overall draw progress
  final List<StrokeData> strokes;
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

      // ── Build path ─────────────────────────────────────
      final fullPath = Path();
      fullPath.moveTo(sc(pts[0]).dx, sc(pts[0]).dy);
      for (int j = 1; j < pts.length; j++) {
        fullPath.lineTo(sc(pts[j]).dx, sc(pts[j]).dy);
      }

      Path path = fullPath;
      if (strokeFrac < 1.0) {
        final metrics = fullPath.computeMetrics().toList();
        if (metrics.isNotEmpty) {
          final metric = metrics.first;
          final extractLength = metric.length * strokeFrac;
          path = metric.extractPath(0.0, extractLength);
          penTip = metric.getTangentForOffset(extractLength)?.position;
        }
      }

      // ── Ink colour — darker core strokes, lighter hair ─
      final isHair = stroke.name.startsWith('hair');
      final isShade = stroke.name.startsWith('cheek');
      final isBeard =
          stroke.name.startsWith('beard') || stroke.name.startsWith('mustache');

      Color inkColor;
      if (isShade) {
        inkColor = Colors.blue.shade300;
      } else if (isHair) {
        inkColor = Colors.blue.shade700;
      } else if (isBeard) {
        inkColor = Colors.blue.shade700;
      } else {
        inkColor = Colors.blue.shade900;
      }

      // ── Subtle sfumato glow under thick strokes ────────
      if (stroke.width >= 1.8) {
        final glowPaint = Paint()
          ..color = Colors.blue.shade200
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

      // Pen tip position is already calculated via PathMetric tangent above
    }

    // ── Pen tip glow ───────────────────────────────────────
    if (penTip != null && progress < 0.99) {
      final glow = 0.5 + 0.5 * glowPulse;

      // Outer halo
      canvas.drawCircle(
        penTip,
        7 * glow,
        Paint()
          ..color = _kCandle.withValues(alpha: 0.25 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Inner bright dot
      canvas.drawCircle(
        penTip,
        2.2,
        Paint()..color = _kCandle.withValues(alpha: 0.85 * glow),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DaVinciFacePainter old) =>
      old.progress != progress || old.glowPulse != glowPulse;
}
