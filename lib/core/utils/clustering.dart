class StrokeData {
  final String id;
  final String? text;
  final bool hasImage;
  final List<double> bounds; // [left, top, right, bottom]
  final List<double> firstPoint; // [dx, dy]

  StrokeData({
    required this.id,
    required this.text,
    required this.hasImage,
    required this.bounds,
    required this.firstPoint,
  });
}

class UnionFind {
  final Map<int, int> parent = {};

  int find(int i) {
    if (parent[i] == null) {
      parent[i] = i;
    }
    if (parent[i] == i) {
      return i;
    }
    return parent[i] = find(parent[i]!);
  }

  void union(int i, int j) {
    int rootI = find(i);
    int rootJ = find(j);
    if (rootI != rootJ) {
      parent[rootI] = rootJ;
    }
  }
}

bool _overlaps(List<double> a, List<double> b) {
  if (a[2] <= b[0] || a[0] >= b[2]) return false;
  if (a[3] <= b[1] || a[1] >= b[3]) return false;
  return true;
}

List<Map<String, dynamic>> performStrokesClustering(List<StrokeData> strokes) {
  final List<StrokeData> drawingStrokes = [];
  final List<StrokeData> nonDrawingStrokes = [];
  
  for (var s in strokes) {
    if (s.text == null && !s.hasImage) {
      drawingStrokes.add(s);
    } else {
      nonDrawingStrokes.add(s);
    }
  }

  final uf = UnionFind();
  final int n = drawingStrokes.length;
  // Inflate bounds by 20.0 to group nearby strokes
  final List<List<double>> boundsList = drawingStrokes.map((s) {
    return [
      s.bounds[0] - 20.0,
      s.bounds[1] - 20.0,
      s.bounds[2] + 20.0,
      s.bounds[3] + 20.0,
    ];
  }).toList();

  for (int i = 0; i < n; i++) {
    uf.find(i);
    for (int j = i + 1; j < n; j++) {
      if (_overlaps(boundsList[i], boundsList[j])) {
        uf.union(i, j);
      }
    }
  }

  final Map<int, List<StrokeData>> clusters = {};
  for (int i = 0; i < n; i++) {
    int root = uf.find(i);
    clusters.putIfAbsent(root, () => []).add(drawingStrokes[i]);
  }

  final canvasObjects = <Map<String, dynamic>>[];
  
  // Add clustered drawing strokes
  for (var entry in clusters.entries) {
    final clusterStrokes = entry.value;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    
    for (var s in clusterStrokes) {
       final b = s.bounds;
       if (b[0] < minX) minX = b[0];
       if (b[1] < minY) minY = b[1];
       if (b[2] > maxX) maxX = b[2];
       if (b[3] > maxY) maxY = b[3];
    }
    
    canvasObjects.add({
      'id': clusterStrokes.first.id,
      'type': 'drawing',
      'stroke_count': clusterStrokes.length,
      'position': [minX, minY],
      'bounds': [minX, minY, maxX, maxY],
    });
  }

  // Add text and images
  for (var stroke in nonDrawingStrokes) {
     if (stroke.text != null) {
        canvasObjects.add({
           'id': stroke.id,
           'type': 'text',
           'content': stroke.text,
           'position': [stroke.firstPoint[0], stroke.firstPoint[1]],
        });
     } else if (stroke.hasImage) {
        canvasObjects.add({
           'id': stroke.id,
           'type': 'image',
           'position': [stroke.firstPoint[0], stroke.firstPoint[1]],
        });
     }
  }

  return canvasObjects;
}
