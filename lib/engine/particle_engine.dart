import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum EasterEggEffect { none, rain, done, fire, snow, love, blackHole }

class ParticleEngine extends StatefulWidget {
  final EasterEggEffect effect;
  final VoidCallback onComplete;

  const ParticleEngine({
    super.key,
    required this.effect,
    required this.onComplete,
  });

  @override
  State<ParticleEngine> createState() => _ParticleEngineState();
}

class _ParticleEngineState extends State<ParticleEngine>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<_Particle> _particles = [];
  final Random _rnd = Random();
  double _timeAlive = 0;
  static const double _maxLifetime = 4.0; // 4 seconds max

  @override
  void initState() {
    super.initState();
    _initParticles();
    _ticker = createTicker((elapsed) {
      _updateParticles(elapsed.inMilliseconds / 1000.0);
    });
    _ticker.start();
  }

  void _initParticles() {
    _particles.clear();
    final effect = widget.effect;

    int count = 0;
    if (effect == EasterEggEffect.rain) {
      count = 150;
    } else if (effect == EasterEggEffect.done)
      count = 100;
    else if (effect == EasterEggEffect.fire)
      count = 120;
    else if (effect == EasterEggEffect.snow)
      count = 100;
    else if (effect == EasterEggEffect.love)
      count = 50;
    else if (effect == EasterEggEffect.blackHole)
      count = 200;

    for (int i = 0; i < count; i++) {
      _particles.add(_createParticle(effect, initial: true));
    }
  }

  _Particle _createParticle(EasterEggEffect effect, {bool initial = false}) {
    // We assume an arbitrary large screen space for emission
    // The painter will use MediaQuery size.
    final p = _Particle();
    p.effect = effect;
    p.lifetime = _rnd.nextDouble() * 2.0 + 1.0;

    if (effect == EasterEggEffect.rain) {
      p.x = _rnd.nextDouble(); // relative 0-1
      p.y = initial ? _rnd.nextDouble() : -0.1;
      p.vx = 0.05 + _rnd.nextDouble() * 0.05;
      p.vy = 0.8 + _rnd.nextDouble() * 0.4;
      p.color = Colors.blue.withOpacity(0.4 + _rnd.nextDouble() * 0.3);
      p.size = 20.0 + _rnd.nextDouble() * 20.0; // length of dash
    } else if (effect == EasterEggEffect.done) {
      p.x = 0.5; // center
      p.y = 0.5;
      final angle = _rnd.nextDouble() * 2 * pi;
      final speed = 0.2 + _rnd.nextDouble() * 0.5;
      p.vx = cos(angle) * speed;
      p.vy = sin(angle) * speed;
      p.color = Colors.primaries[_rnd.nextInt(Colors.primaries.length)];
      p.size = 6.0 + _rnd.nextDouble() * 8.0;
      p.rot = _rnd.nextDouble() * pi;
      p.rotSpeed = (_rnd.nextDouble() - 0.5) * 4;
      p.gravity = 0.5;
    } else if (effect == EasterEggEffect.fire) {
      p.x = _rnd.nextDouble();
      p.y = 1.1; // start below
      p.vx = (_rnd.nextDouble() - 0.5) * 0.1;
      p.vy = -0.3 - _rnd.nextDouble() * 0.3;
      p.color = _rnd.nextBool()
          ? Colors.orange
          : (_rnd.nextBool() ? Colors.red : Colors.yellow);
      p.size = 10.0 + _rnd.nextDouble() * 15.0;
      p.gravity = -0.2; // flows up
    } else if (effect == EasterEggEffect.snow) {
      p.x = _rnd.nextDouble();
      p.y = initial ? _rnd.nextDouble() : -0.1;
      p.vx = (_rnd.nextDouble() - 0.5) * 0.1;
      p.vy = 0.1 + _rnd.nextDouble() * 0.2;
      p.color = Colors.white.withOpacity(0.6 + _rnd.nextDouble() * 0.4);
      p.size = 4.0 + _rnd.nextDouble() * 6.0;
      p.rotSpeed = (_rnd.nextDouble() - 0.5) * 2;
    } else if (effect == EasterEggEffect.blackHole) {
      // Swirling particles around the center
      final angle = _rnd.nextDouble() * 2 * pi;
      final dist = 0.1 + _rnd.nextDouble() * 0.4;
      p.x = 0.5 + cos(angle) * dist;
      p.y = 0.5 + sin(angle) * dist;
      // Velocity is tangential + inwards
      p.vx = -sin(angle) * 0.5 - cos(angle) * 0.2;
      p.vy = cos(angle) * 0.5 - sin(angle) * 0.2;
      p.color = _rnd.nextBool() ? Colors.deepPurpleAccent : Colors.black87;
      p.size = 2.0 + _rnd.nextDouble() * 4.0;
      p.rotSpeed = 5.0;
    } else if (effect == EasterEggEffect.love) {
      p.x = _rnd.nextDouble();
      p.y = initial ? _rnd.nextDouble() : 1.1; // start from bottom
      p.vx = (_rnd.nextDouble() - 0.5) * 0.2;
      p.vy = -0.2 - _rnd.nextDouble() * 0.3; // float up
      p.color = Colors.pinkAccent.withOpacity(0.7 + _rnd.nextDouble() * 0.3);
      p.size = 15.0 + _rnd.nextDouble() * 20.0;
      p.rotSpeed = (_rnd.nextDouble() - 0.5) * 2;
    }

    return p;
  }

  double _lastTime = 0;
  void _updateParticles(double currentTime) {
    if (_lastTime == 0) _lastTime = currentTime;
    double dt = currentTime - _lastTime;
    _lastTime = currentTime;

    _timeAlive += dt;
    if (_timeAlive > _maxLifetime) {
      _ticker.stop();
      widget.onComplete();
      return;
    }

    setState(() {
      for (int i = 0; i < _particles.length; i++) {
        var p = _particles[i];
        p.age += dt;

        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += p.gravity * dt;
        p.rot += p.rotSpeed * dt;

        if (widget.effect == EasterEggEffect.snow) {
          p.x += sin(currentTime * 2 + p.age) * 0.05 * dt; // wind drift
        } else if (widget.effect == EasterEggEffect.love) {
          p.x += sin(currentTime * 3 + p.age) * 0.1 * dt; // sway left and right
        } else if (widget.effect == EasterEggEffect.fire) {
          p.size *= (1 - dt * 0.5); // shrink
        } else if (widget.effect == EasterEggEffect.blackHole) {
          // Increase inward pull over time
          final dx = 0.5 - p.x;
          final dy = 0.5 - p.y;
          p.vx += dx * dt * 2;
          p.vy += dy * dt * 2;
        }

        // respawn if out of bounds (except for done/bursts/blackHole)
        if (widget.effect != EasterEggEffect.done &&
            widget.effect != EasterEggEffect.blackHole &&
            _timeAlive < _maxLifetime - 1.0) {
          if (p.y > 1.2 || p.y < -0.2 || p.age > p.lifetime) {
            _particles[i] = _createParticle(widget.effect);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(_particles, widget.effect),
        child: Container(),
      ),
    );
  }
}

class _Particle {
  late EasterEggEffect effect;
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double rot = 0;
  double rotSpeed = 0;
  double gravity = 0;
  Color color = Colors.white;
  double size = 10;
  double age = 0;
  double lifetime = 1;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final EasterEggEffect effect;

  _ParticlePainter(this.particles, this.effect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var p in particles) {
      if (p.y > 1.2 || p.y < -0.2) continue; // cull

      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rot);

      paint.color = p.color;

      if (effect == EasterEggEffect.rain) {
        paint.strokeWidth = 2;
        paint.strokeCap = StrokeCap.round;
        // Parallax dash
        canvas.drawLine(Offset.zero, Offset(p.vx * 100, p.size), paint);
      } else if (effect == EasterEggEffect.done) {
        // Confetti square
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else if (effect == EasterEggEffect.fire) {
        // Glow circle
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(Offset.zero, p.size, paint);
      } else if (effect == EasterEggEffect.snow) {
        // Simple hexagon/circle
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (effect == EasterEggEffect.love) {
        // Heart
        _drawHeart(canvas, paint, p.size);
      } else if (effect == EasterEggEffect.blackHole) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset.zero, p.size, paint);
      }

      canvas.restore();
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, double size) {
    final path = Path();
    path.moveTo(0, size * 0.3);
    path.cubicTo(-size * 0.5, -size * 0.3, -size * 1.2, size * 0.3, 0, size);
    path.cubicTo(
      size * 1.2,
      size * 0.3,
      size * 0.5,
      -size * 0.3,
      0,
      size * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
