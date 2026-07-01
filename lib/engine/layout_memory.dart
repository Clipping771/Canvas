import 'dart:ui';
import '../models/spatial_node.dart';

class LayoutMemoryEntry {
  final Rect bounds;
  final DateTime recordedAt;

  LayoutMemoryEntry(this.bounds) : recordedAt = DateTime.now();

  double get decayFactor {
    final diff = DateTime.now().difference(recordedAt).inSeconds;
    // Decay over 5 minutes (300 seconds)
    // 0 seconds = 1.0 (full influence)
    // 300 seconds = 0.0 (no influence)
    if (diff > 300) return 0.0;
    return 1.0 - (diff / 300.0);
  }
}

class GlobalLayoutMemory {
  final Map<String, LayoutMemoryEntry> _history = {}; // groupId -> memory

  void recordNode(SpatialNode node) {
    _history[node.groupId] = LayoutMemoryEntry(node.bounds);
  }

  void clearMemory() {
    _history.clear();
  }

  List<LayoutMemoryEntry> getActiveConstraints() {
    // Remove expired entries
    _history.removeWhere((key, entry) => entry.decayFactor <= 0.0);
    return _history.values.toList();
  }
  
  Rect? getPreviousBounds(String groupId) {
    return _history[groupId]?.bounds;
  }
}
