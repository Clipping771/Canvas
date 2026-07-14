// ignore_for_file: dead_code, unused_label
import 'dart:ui';
import 'package:vinci_board/core/models/ai/spawn_context.dart';
import 'package:vinci_board/core/models/ai/spawn_location.dart';

abstract class SpawnPolicy {
  SpawnLocation getSpawn(SpawnContext context, Size itemSize);
}

class ViewportSpawnPolicy implements SpawnPolicy {
  @override
  SpawnLocation getSpawn(SpawnContext context, Size itemSize) {
    // Center in the viewport
    Offset center = context.viewportRect.center;
    Offset position = Offset(
      center.dx - itemSize.width / 2,
      center.dy - itemSize.height / 2,
    );

    return SpawnLocation(
      position: position,
      needsCameraMove: true,
      reason: 'viewport',
    );
  }
}

class ConversationSpawnPolicy implements SpawnPolicy {
  @override
  SpawnLocation getSpawn(SpawnContext context, Size itemSize) {
    if (context.lastAiSpawnPosition != null) {
      // Spawn below the last item
      return SpawnLocation(
        position: Offset(
          context.lastAiSpawnPosition!.dx,
          context.lastAiSpawnPosition!.dy +
              200, // Fixed offset for now, ideally itemSize.height of previous item + padding
        ),
        needsCameraMove: true,
        reason: 'conversation',
      );
    }

    // Fallback to viewport
    return ViewportSpawnPolicy().getSpawn(context, itemSize);
  }
}

class SelectionSpawnPolicy implements SpawnPolicy {
  @override
  SpawnLocation getSpawn(SpawnContext context, Size itemSize) {
    if (context.selectedStrokes.isEmpty) {
      return ViewportSpawnPolicy().getSpawn(context, itemSize);
    }

    // Calculate bounds of selection
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var stroke in context.selectedStrokes) {
      for (var point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    // Add padding
    final padding = 40.0;

    // Check right space
    Offset rightPos = Offset(maxX + padding, minY);
    bool rightSpaceClear =
        true; // In full impl, check context.existingObjectBounds

    if (rightSpaceClear) {
      return SpawnLocation(
        position: rightPos,
        needsCameraMove: true, // Will check visibility later
        reason: 'selection_right',
      );
    }

    // Fallback to right for now
    return SpawnLocation(
      position: rightPos,
      needsCameraMove: true,
      reason: 'selection_right',
    );
  }
}
