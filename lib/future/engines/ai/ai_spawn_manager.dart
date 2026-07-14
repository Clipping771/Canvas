// ignore_for_file: unreachable_switch_default
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/engines/ai/spawn_policies.dart';
import 'package:vinci_board/engines/ai/collision_resolver.dart';
import 'package:vinci_board/core/models/ai/spawn_context.dart';
import 'package:vinci_board/core/models/ai/spawn_location.dart';
import 'package:vinci_board/core/models/ai/spawn_strategy.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/core/canvas/canvas_controller.dart';
import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';

final aiSpawnManagerProvider = Provider<AiSpawnManager>((ref) {
  return AiSpawnManager(ref);
});

class AiSpawnManager {
  final Ref _ref;
  final CollisionResolver _collisionResolver = SpiralCollisionResolver();
  Offset? _lastAiSpawnPosition;

  AiSpawnManager(this._ref);

  SpawnLocation getOptimalSpawn(
    SpawnStrategy strategy,
    Size itemSize,
    Size screenSize, {
    List<Rect> additionalBounds = const [],
  }) {
    final drawingState = _ref.read(drawingProvider);
    final canvasController = _ref.read(canvasControllerProvider);

    final viewportRect = canvasController.getViewportRect(screenSize);

    final existingBounds = drawingState.strokes.map((s) => s.bounds).toList();
    existingBounds.addAll(additionalBounds);

    final spawnContext = SpawnContext(
      lastAiSpawnPosition: _lastAiSpawnPosition,
      selectedStrokes: drawingState.selectedStrokes,
      viewportRect: viewportRect,
      existingObjectBounds: existingBounds,
    );

    SpawnPolicy? policy;

    switch (strategy) {
      case SpawnStrategy.nearSelection:
        policy = SelectionSpawnPolicy();
        break;
      case SpawnStrategy.viewport:
        policy = ViewportSpawnPolicy();
        break;
      case SpawnStrategy.conversation:
        policy = ConversationSpawnPolicy();
        break;
      case SpawnStrategy.manual:
        policy = ViewportSpawnPolicy(); // Fallback for manual
        break;
      case SpawnStrategy.auto:
        if (spawnContext.selectedStrokes.isNotEmpty) {
        } else if (spawnContext.lastAiSpawnPosition != null) {
          policy = ConversationSpawnPolicy();
        } else {
          policy = ViewportSpawnPolicy();
        }
        break;
    }

    SpawnLocation location = policy!.getSpawn(spawnContext, itemSize);

    // Resolve collision
    Offset resolvedPos = _collisionResolver.resolve(
      location.position,
      itemSize,
      existingBounds,
    );

    // Update last spawn position
    _lastAiSpawnPosition = resolvedPos;

    return SpawnLocation(
      position: resolvedPos,
      needsCameraMove: location.needsCameraMove,
      reason: location.reason,
    );
  }

  void onSpawnComplete(SpawnLocation location) {
    if (location.needsCameraMove) {
      _ref
          .read(eventBusProvider)
          .publish(
            BaseEvent.generic('aiSpawnCompleted', payload: location.position),
          );
    }
  }
}
