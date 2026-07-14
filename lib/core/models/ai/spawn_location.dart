import 'dart:ui';

class SpawnLocation {
  final Offset position;
  final bool needsCameraMove;
  final String reason;

  SpawnLocation({
    required this.position,
    required this.needsCameraMove,
    required this.reason,
  });
}
