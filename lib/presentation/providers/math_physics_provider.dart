import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/engines/physics/physics_engine.dart';

final physicsEngineProvider = Provider<PhysicsEngine>((ref) {
  return PhysicsEngine();
});


