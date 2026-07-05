import 'package:flutter/material.dart';
import '../../models/stroke.dart';
import '../../models/tool_type.dart';

class WireEngine {
  /// Updates the paths of all wire strokes to snap to their connected objects
  /// and draws a beautiful sagging bezier curve between them.
  static List<Stroke> updateWires(List<Stroke> strokes) {
    final updatedStrokes = List<Stroke>.from(strokes);
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

            final newPoints = _generateBezierPoints(sourceCenter, targetCenter);
            
            finalStrokeList.add(Stroke(
              id: stroke.id,
              groupId: stroke.groupId,
              name: stroke.name,
              points: newPoints,
              color: stroke.color,
              size: stroke.size,
              rotation: stroke.rotation,
              toolType: stroke.toolType,
              text: stroke.text,
              imageBytes: stroke.imageBytes,
              decodedImage: stroke.decodedImage,
              isFilled: stroke.isFilled,
              semanticMeaning: stroke.semanticMeaning,
              physicsEnabled: stroke.physicsEnabled,
              customMetadata: stroke.customMetadata,
              version: stroke.version,
            ));
            continue;
          }
        }
      }
      finalStrokeList.add(stroke);
    }
    
    return simulateCircuit(finalStrokeList);
  }

  /// Traverses the connections (Wires and Portals) to find connected components.
  /// If a "Light" text stroke is connected to a "Battery" text stroke, it turns yellow.
  static List<Stroke> simulateCircuit(List<Stroke> strokes) {
    final Map<String, Stroke> strokeMap = {for (var s in strokes) s.id: s};
    
    // Build adjacency list for undirected graph
    final Map<String, Set<String>> graph = {};
    for (var s in strokes) {
      graph[s.id] = {};
    }

    // Connect wires
    for (var s in strokes) {
      if (s.toolType == ToolType.wire) {
        final sourceId = s.customMetadata?['sourceId'] as String?;
        final targetId = s.customMetadata?['targetId'] as String?;
        if (sourceId != null && targetId != null) {
          graph[sourceId]?.add(targetId);
          graph[targetId]?.add(sourceId);
        }
      } else if (s.toolType == ToolType.portal) {
        final destId = s.customMetadata?['destinationId'] as String?;
        if (destId != null) {
          graph[s.id]?.add(destId);
          graph[destId]?.add(s.id);
        }
      }
    }

    // Find components
    final Set<String> visited = {};
    final List<Set<String>> components = [];

    for (var nodeId in graph.keys) {
      if (!visited.contains(nodeId)) {
        final Set<String> component = {};
        final List<String> queue = [nodeId];
        visited.add(nodeId);

        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          component.add(current);

          for (var neighbor in graph[current] ?? <String>{}) {
            if (!visited.contains(neighbor)) {
              visited.add(neighbor);
              queue.add(neighbor);
            }
          }
        }
        components.add(component);
      }
    }

    // Apply circuit logic: If a component has "Battery" (case-insensitive), all "Light" strokes in it turn yellow
    final List<Stroke> simulatedStrokes = [];
    for (var s in strokes) {
      if (s.toolType == ToolType.text && s.text != null && s.text!.toLowerCase() == 'light') {
        // Find component containing this light
        final component = components.firstWhere((c) => c.contains(s.id), orElse: () => {});
        bool hasPower = false;
        for (var id in component) {
          final compStroke = strokeMap[id];
          if (compStroke != null && compStroke.toolType == ToolType.text && compStroke.text != null && compStroke.text!.toLowerCase() == 'battery') {
            hasPower = true;
            break;
          }
        }

        final targetColor = hasPower ? Colors.yellow.shade600 : Colors.grey;
        if (s.color != targetColor) {
           simulatedStrokes.add(Stroke(
              id: s.id,
              groupId: s.groupId,
              name: s.name,
              points: s.points,
              color: targetColor,
              size: s.size,
              rotation: s.rotation,
              toolType: s.toolType,
              text: s.text,
              imageBytes: s.imageBytes,
              decodedImage: s.decodedImage,
              isFilled: s.isFilled,
              semanticMeaning: s.semanticMeaning,
              physicsEnabled: s.physicsEnabled,
              customMetadata: s.customMetadata,
              version: s.version + 1,
            ));
            continue;
        }
      }
      simulatedStrokes.add(s);
    }

    return simulatedStrokes;
  }

  static List<Offset> _generateBezierPoints(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
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
