import 'dart:ui';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/simulation_world.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/body.dart';
import 'package:vinci_board/engines/physics/physics_v2/core/constraint_solver.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';

/// Layer 5: The AI Lab
/// Translates high-level natural language intents into complex physics experiments.
class PhysicsAILab {
  static final PhysicsAILab _instance = PhysicsAILab._internal();
  factory PhysicsAILab() => _instance;
  PhysicsAILab._internal();

  /// Parses a natural language intent and returns a list of strokes to be added to the canvas,
  /// while also rigging up the underlying SimulationWorld.
  List<Stroke> buildExperiment(String intent, SimulationWorld world) {
    intent = intent.toLowerCase();

    if (intent.contains('pendulum')) {
      return _buildPendulum(world);
    }

    if (intent.contains('spring')) {
      return _buildSpringMass(world);
    }

    return [];
  }

  List<Stroke> _buildPendulum(SimulationWorld world) {
    const uuid = Uuid();
    final pivotId = uuid.v4();
    final bobId = uuid.v4();

    final pivotPosition = const Offset(400, 200);
    final bobPosition = const Offset(550, 400);

    // 1. Create Pivot (Static Body)
    final pivotBody = PhysicsBody(
      id: pivotId,
      type: BodyType.staticBody,
      position: pivotPosition,
    );

    // 2. Create Bob (Dynamic Body)
    final bobBody = PhysicsBody(
      id: bobId,
      type: BodyType.dynamicBody,
      mass: 5.0,
      position: bobPosition,
    );

    // 3. Connect with a very stiff spring (acting as a rigid rope)
    final rope = SpringConstraint(
      bodyA: pivotBody,
      bodyB: bobBody,
      restLength: (bobPosition - pivotPosition).distance,
      stiffness: 500.0, // High stiffness = rigid rope
      damping: 2.0, // Low damping = swings for a long time
    );

    world.addBody(pivotBody);
    world.addBody(bobBody);
    world.addConstraint(rope);

    // 4. Generate visual UI Strokes
    final pivotStroke = _generateCircleStroke(
      pivotId,
      pivotPosition,
      10,
      const Color(0xFF333333),
    );
    final bobStroke = _generateCircleStroke(
      bobId,
      bobPosition,
      30,
      const Color(0xFFE53935),
      physicsEnabled: true,
    );

    return [pivotStroke, bobStroke];
  }

  List<Stroke> _buildSpringMass(SimulationWorld world) {
    const uuid = Uuid();
    final anchorId = uuid.v4();
    final massId = uuid.v4();

    final anchorPos = const Offset(400, 100);
    final massPos = const Offset(400, 400);

    final anchorBody = PhysicsBody(
      id: anchorId,
      type: BodyType.staticBody,
      position: anchorPos,
    );

    final massBody = PhysicsBody(
      id: massId,
      type: BodyType.dynamicBody,
      mass: 10.0,
      position: massPos,
    );

    final spring = SpringConstraint(
      bodyA: anchorBody,
      bodyB: massBody,
      restLength: 150.0,
      stiffness: 40.0, // bouncy
      damping: 1.5,
    );

    world.addBody(anchorBody);
    world.addBody(massBody);
    world.addConstraint(spring);

    final anchorStroke = _generateRectStroke(
      anchorId,
      anchorPos,
      80,
      20,
      const Color(0xFF333333),
    );
    final massStroke = _generateRectStroke(
      massId,
      massPos,
      60,
      60,
      const Color(0xFF1E88E5),
      physicsEnabled: true,
    );

    return [anchorStroke, massStroke];
  }

  // Helper to generate visual strokes
  Stroke _generateCircleStroke(
    String id,
    Offset center,
    double radius,
    Color color, {
    bool physicsEnabled = false,
  }) {
    List<Offset> points = [];
    for (int i = 0; i <= 30; i++) {
      double angle = (i / 30) * 2 * 3.14159;
      points.add(
        center + Offset(radius * math.cos(angle), radius * math.sin(angle)),
      );
    }
    return Stroke(
      id: id,
      points: points,
      color: color,
      size: 4.0,
      toolType: ToolType.pen,
      isFilled: true,
      physicsEnabled: physicsEnabled,
    );
  }

  Stroke _generateRectStroke(
    String id,
    Offset center,
    double w,
    double h,
    Color color, {
    bool physicsEnabled = false,
  }) {
    List<Offset> points = [
      center + Offset(-w / 2, -h / 2),
      center + Offset(w / 2, -h / 2),
      center + Offset(w / 2, h / 2),
      center + Offset(-w / 2, h / 2),
      center + Offset(-w / 2, -h / 2), // Close loop
    ];
    return Stroke(
      id: id,
      points: points,
      color: color,
      size: 4.0,
      toolType: ToolType.pen,
      isFilled: true,
      physicsEnabled: physicsEnabled,
    );
  }
}
