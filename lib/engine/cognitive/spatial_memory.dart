import 'dart:ui';
import '../../models/stroke.dart';

class QuadtreeNode {
  final Rect bounds;
  final int capacity;
  final List<Stroke> strokes = [];
  bool divided = false;
  
  QuadtreeNode? nw, ne, sw, se;

  QuadtreeNode(this.bounds, this.capacity);

  void subdivide() {
    double x = bounds.left;
    double y = bounds.top;
    double w = bounds.width / 2;
    double h = bounds.height / 2;

    nw = QuadtreeNode(Rect.fromLTWH(x, y, w, h), capacity);
    ne = QuadtreeNode(Rect.fromLTWH(x + w, y, w, h), capacity);
    sw = QuadtreeNode(Rect.fromLTWH(x, y + h, w, h), capacity);
    se = QuadtreeNode(Rect.fromLTWH(x + w, y + h, w, h), capacity);
    divided = true;
  }

  bool insert(Stroke stroke) {
    if (!bounds.overlaps(stroke.bounds)) return false;

    if (strokes.length < capacity) {
      strokes.add(stroke);
      return true;
    }

    if (!divided) subdivide();

    return nw!.insert(stroke) || ne!.insert(stroke) || sw!.insert(stroke) || se!.insert(stroke);
  }

  void query(Rect range, List<Stroke> found) {
    if (!bounds.overlaps(range)) return;

    for (var s in strokes) {
      if (range.overlaps(s.bounds)) {
        found.add(s);
      }
    }

    if (divided) {
      nw!.query(range, found);
      ne!.query(range, found);
      sw!.query(range, found);
      se!.query(range, found);
    }
  }
}

class SpatialMemory {
  late QuadtreeNode root;
  
  SpatialMemory() {
    _reset();
  }

  void _reset() {
    // Canvas bounds - ideally this expands dynamically
    root = QuadtreeNode(const Rect.fromLTWH(-10000, -10000, 20000, 20000), 10);
  }

  void rebuild(List<Stroke> strokes) {
    _reset();
    for (var stroke in strokes) {
      root.insert(stroke);
    }
  }

  List<Stroke> queryRegion(Rect region) {
    final found = <Stroke>[];
    root.query(region, found);
    return found.toSet().toList(); // Remove duplicates
  }
}
