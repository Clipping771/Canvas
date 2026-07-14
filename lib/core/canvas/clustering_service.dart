import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:vinci_board/core/models/stroke.dart';

class ClusteringService {
  /// Runs the O(N^2) Union-Find clustering algorithm in a separate isolate
  /// so it never blocks the main UI thread, even for 100,000+ strokes.
  static Future<List<Map<String, dynamic>>> clusterStrokesAsync({
    required List<Stroke> strokes,
    required Matrix4 transform,
    required double pixelRatio,
  }) async {
    if (strokes.isEmpty) return [];

    // Map necessary primitive data to pass to the isolate.
    // Passing full Stroke objects can be expensive in terms of memory copying.
    final rawData = strokes.map((s) => {
      'id': s.id,
      'bounds': s.bounds,
    }).toList();

    final result = await compute(_clusterIsolate, {
      'strokes': rawData,
      'transform': transform.storage,
      'pixelRatio': pixelRatio,
    });

    return result;
  }

  static List<Map<String, dynamic>> _clusterIsolate(Map<String, dynamic> data) {
    final rawStrokes = data['strokes'] as List<Map<String, dynamic>>;
    final transformStorage = data['transform'] as List<double>;
    final pixelRatio = data['pixelRatio'] as double;
    
    final transform = Matrix4.fromList(transformStorage);

    final boundsList = rawStrokes
        .map((s) => MatrixUtils.transformRect(transform, s['bounds'] as Rect).inflate(20.0))
        .toList();
        
    final n = rawStrokes.length;
    final parent = List<int>.generate(n, (i) => i);

    int find(int i) {
      int root = i;
      while (root != parent[root]) {
        root = parent[root];
      }
      int curr = i;
      while (curr != root) {
        int nxt = parent[curr];
        parent[curr] = root;
        curr = nxt;
      }
      return root;
    }

    void union(int i, int j) {
      final rootI = find(i);
      final rootJ = find(j);
      if (rootI != rootJ) {
        parent[rootI] = rootJ;
      }
    }

    // Connect overlapping bounds
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if (boundsList[i].overlaps(boundsList[j])) {
          union(i, j);
        }
      }
    }

    // Group strokes by root parent
    final groups = <int, List<Map<String, dynamic>>>{};
    for (int i = 0; i < n; i++) {
      final root = find(i);
      groups.putIfAbsent(root, () => []).add(rawStrokes[i]);
    }

    final clusters = groups.values.toList();
    final canvasObjects = <Map<String, dynamic>>[];

    for (var cluster in clusters) {
      Rect b = MatrixUtils.transformRect(transform, cluster.first['bounds'] as Rect);
      for (int i = 1; i < cluster.length; i++) {
        b = b.expandToInclude(
          MatrixUtils.transformRect(transform, cluster[i]['bounds'] as Rect),
        );
      }

      canvasObjects.add({
        'type': 'raw_handwriting_or_sketch',
        'stroke_count': cluster.length,
        'ids': cluster.map((e) => e['id']).toList(),
        'bounds': [
          (b.left * pixelRatio).toInt(),
          (b.top * pixelRatio).toInt(),
          (b.width * pixelRatio).toInt(),
          (b.height * pixelRatio).toInt(),
        ],
      });
    }

    return canvasObjects;
  }
}
