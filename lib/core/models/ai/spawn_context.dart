import 'dart:ui';
import 'package:vinci_board/core/models/stroke.dart';

class SpawnContext {
  final Offset? lastAiSpawnPosition;
  final List<Stroke> selectedStrokes;
  final Rect viewportRect;
  final List<Rect> existingObjectBounds;

  SpawnContext({
    this.lastAiSpawnPosition,
    required this.selectedStrokes,
    required this.viewportRect,
    required this.existingObjectBounds,
  });
}
