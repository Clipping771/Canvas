import 'dart:math';
import 'package:flutter/material.dart';
import '../models/spatial_node.dart';
import 'weight_controller.dart';
import 'layout_memory.dart';

class SpatialLayoutEngine {
  final GlobalLayoutMemory memory;

  SpatialLayoutEngine(this.memory);

  Offset computeOptimalPlacement({
    required Size nodeSize,
    required Rect? parentBounds,
    required Rect viewportBounds,
    required Set<InteractionContext> contexts,
    required String groupId,
  }) {
    final weights = ContextAwareWeightController.getWeights(contexts);
    
    // Generate candidates
    List<Offset> candidates = _generateCandidates(nodeSize, parentBounds, viewportBounds);
    
    Offset bestCandidate = candidates.first;
    double lowestCost = double.infinity;
    
    final activeConstraints = memory.getActiveConstraints();
    final previousBounds = memory.getPreviousBounds(groupId);

    for (var candidate in candidates) {
      final candidateRect = Rect.fromLTWH(candidate.dx, candidate.dy, nodeSize.width, nodeSize.height);
      
      // 1. Collision Cost
      double collisionCost = 0.0;
      for (var constraint in activeConstraints) {
        if (candidateRect.overlaps(constraint.bounds)) {
          // Add cost proportional to overlap area and decay factor
          final overlap = candidateRect.intersect(constraint.bounds);
          final overlapArea = overlap.width * overlap.height;
          collisionCost += overlapArea * constraint.decayFactor;
        }
      }
      
      // 2. Distance Cost
      double distanceCost = 0.0;
      if (parentBounds != null) {
        final dist = (candidateRect.center - parentBounds.center).distance;
        distanceCost = dist;
      }
      
      // 3. Viewport Cost
      double viewportCost = 0.0;
      if (!viewportBounds.contains(candidateRect.center)) {
        viewportCost = 10000.0; // High penalty for center being outside viewport
      }
      // Also penalty for clipping
      if (candidateRect.left < viewportBounds.left) viewportCost += viewportBounds.left - candidateRect.left;
      if (candidateRect.right > viewportBounds.right) viewportCost += candidateRect.right - viewportBounds.right;
      if (candidateRect.top < viewportBounds.top) viewportCost += viewportBounds.top - candidateRect.top;
      if (candidateRect.bottom > viewportBounds.bottom) viewportCost += candidateRect.bottom - viewportBounds.bottom;
      
      // 4. Inertia Cost
      double inertiaCost = 0.0;
      if (previousBounds != null) {
         inertiaCost = (candidateRect.topLeft - previousBounds.topLeft).distance;
      }
      
      // Normalize costs (heuristic scaling)
      collisionCost = collisionCost / 1000.0; 
      distanceCost = distanceCost / 100.0;
      viewportCost = viewportCost / 100.0;
      inertiaCost = inertiaCost / 100.0;
      
      double totalCost = 
        (collisionCost * weights.collisionWeight) +
        (distanceCost * weights.distanceWeight) +
        (viewportCost * weights.viewportWeight) +
        (inertiaCost * weights.inertiaWeight);
        
      if (totalCost < lowestCost) {
        lowestCost = totalCost;
        bestCandidate = candidate;
      }
    }
    
    return bestCandidate;
  }
  
  List<Offset> _generateCandidates(Size size, Rect? parentBounds, Rect viewportBounds) {
    if (parentBounds == null) {
      // Standalone: try viewport center, and some offsets
      final center = viewportBounds.center;
      return [
        Offset(center.dx - size.width/2, center.dy - size.height/2),
        Offset(center.dx - size.width/2, viewportBounds.top + 50),
        Offset(center.dx - size.width/2, viewportBounds.bottom - size.height - 50),
      ];
    }
    
    // Branching: below, right, left, above (with some padding)
    const double pad = 40.0;
    return [
      Offset(parentBounds.left, parentBounds.bottom + pad), // Below
      Offset(parentBounds.right + pad, parentBounds.top), // Right
      Offset(parentBounds.left - size.width - pad, parentBounds.top), // Left
      Offset(parentBounds.left, parentBounds.top - size.height - pad), // Above
      Offset(parentBounds.right + pad, parentBounds.bottom + pad), // Bottom-Right diagonal
    ];
  }
}
