import 'dart:ui';
import 'task_scheduler.dart';
import '../../models/stroke.dart';

class PhysicsBody {
  Offset position;
  Offset velocity;
  final double mass;
  final double radius;
  final Stroke strokeRef;

  PhysicsBody({
    required this.position,
    required this.velocity,
    required this.mass,
    required this.radius,
    required this.strokeRef,
  });
}

class PhysicsEngine implements CognitiveSubsystem {
  final List<PhysicsBody> _bodies = [];
  Offset gravity = const Offset(0, 9.8); // Gentle gravity
  
  void addBody(PhysicsBody body) {
    _bodies.add(body);
  }

  void clear() {
    _bodies.clear();
  }

  @override
  TaskPriority get priority => TaskPriority.realtime; // 60fps

  @override
  bool get isActive => _bodies.isNotEmpty;

  @override
  void onTick(Duration elapsed) {
    double dt = elapsed.inMicroseconds / 1000000.0;
    
    // Euler integration
    for (var body in _bodies) {
      body.velocity += gravity * dt;
      body.position += body.velocity * dt;
      
      // Simple floor collision
      if (body.position.dy > 10000) {
        body.position = Offset(body.position.dx, 10000);
        body.velocity = Offset(body.velocity.dx, -body.velocity.dy * 0.6); // Bounce
      }
    }
    
    // Update stroke bounds/points to match physics bodies
    // (In production, this would trigger a UI repaint)
  }
}
