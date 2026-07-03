import 'package:flutter/material.dart';
import '../../models/stroke.dart';
import '../../models/tool_type.dart';

class WireEngine {
  /// Updates the paths of all wire strokes to connect their source and target objects.
  /// Also handles routing wires through portals if the connected objects have jumped.
  static List<Stroke> updateWires(List<Stroke> strokes) {
    final updatedStrokes = List<Stroke>.from(strokes);
    final portals = strokes.where((s) => s.toolType == ToolType.portal).toList();
    final Map<String, Stroke> strokeMap = {for (var s in strokes) s.id: s};
    final List<Stroke> finalStrokeList = [];

    for (int i = 0; i < updatedStrokes.length; i++) {
      final stroke = updatedStrokes[i];
      if (stroke.toolType == ToolType.wire) {
        final sourceId = stroke.customMetadata?['sourceId'] as String?;
        final targetId = stroke.customMetadata?['targetId'] as String?;
        
        if (sourceId != null && targetId != null) {
          final sourceStroke = strokeMap[sourceId];
          final targetStroke = strokeMap[targetId];
          
          if (sourceStroke != null && targetStroke != null) {
            // Recalculate wire points
            final sourceCenter = sourceStroke.bounds.center;
            final targetCenter = targetStroke.bounds.center;

            final jumpPortalId1 = sourceStroke.customMetadata?['lastPortalId'] as String?;
            final jumpPortalId2 = targetStroke.customMetadata?['lastPortalId'] as String?;

            List<Offset> newPoints = [];
            Map<String, dynamic> newMeta = stroke.customMetadata != null 
                ? Map<String, dynamic>.from(stroke.customMetadata!) 
                : {};
            
            if (jumpPortalId1 != null || jumpPortalId2 != null) {
               // Complex case: routed through portals
               final sourceLastPortal = jumpPortalId1 != null ? strokeMap[jumpPortalId1] : null;
               
               if (sourceLastPortal != null && sourceLastPortal.customMetadata?['destinationId'] != null) {
                 final sourceOriginPortalId = sourceLastPortal.customMetadata!['destinationId'] as String;
                 final sourceOriginPortal = strokeMap[sourceOriginPortalId];
                 
                 if (sourceOriginPortal != null) {
                    final firstSegment = _generateBezierPoints(targetCenter, sourceOriginPortal.bounds.center);
                    newPoints.addAll(firstSegment);
                    newMeta['jumpIndices'] = [firstSegment.length];
                    newPoints.addAll(_generateBezierPoints(sourceLastPortal.bounds.center, sourceCenter));
                 } else {
                    newPoints = _generateBezierPoints(sourceCenter, targetCenter);
                    newMeta.remove('jumpIndices');
                 }
               } else {
                  newPoints = _generateBezierPoints(sourceCenter, targetCenter);
                  newMeta.remove('jumpIndices');
               }
            } else {
               newPoints = _generateBezierPoints(sourceCenter, targetCenter);
               newMeta.remove('jumpIndices');
            }
            
            finalStrokeList.add(Stroke(
              id: stroke.id,
              groupId: stroke.groupId,
              name: stroke.name,
              points: newPoints,
              color: stroke.color,
              size: stroke.size,
              rotation: stroke.rotation,
              toolType: stroke.toolType,
              isFilled: stroke.isFilled,
              customMetadata: newMeta,
            ));
          }
          // If source or target is null, the wire is orphaned and is naturally dropped
        }
      } else {
        finalStrokeList.add(stroke);
      }
    }
    
    return finalStrokeList;
  }

  static List<Offset> _generateBezierPoints(Offset p1, Offset p2) {
    // Generate a simple quadratic bezier curve for the wire
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    // Add some sag to the wire
    final controlPoint = Offset(
      p1.dx + dx / 2,
      p1.dy + dy / 2 + (dx.abs() * 0.2).clamp(20.0, 100.0),
    );

    final points = <Offset>[];
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = (1 - t) * (1 - t) * p1.dx + 2 * (1 - t) * t * controlPoint.dx + t * t * p2.dx;
      final y = (1 - t) * (1 - t) * p1.dy + 2 * (1 - t) * t * controlPoint.dy + t * t * p2.dy;
      points.add(Offset(x, y));
    }
    return points;
  }
}
