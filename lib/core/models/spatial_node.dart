import 'dart:ui';

enum SemanticType { root, expansion, clarification, detail }

class SpatialNode {
  final String groupId;
  final String clusterId;
  final String? parentId;
  final Rect bounds;
  final int depth;
  final int orderIndex;
  final SemanticType semanticType;
  final DateTime createdAt;

  SpatialNode({
    required this.groupId,
    required this.clusterId,
    this.parentId,
    required this.bounds,
    required this.depth,
    required this.orderIndex,
    required this.semanticType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  SpatialNode copyWith({
    String? groupId,
    String? clusterId,
    String? parentId,
    Rect? bounds,
    int? depth,
    int? orderIndex,
    SemanticType? semanticType,
  }) {
    return SpatialNode(
      groupId: groupId ?? this.groupId,
      clusterId: clusterId ?? this.clusterId,
      parentId: parentId ?? this.parentId,
      bounds: bounds ?? this.bounds,
      depth: depth ?? this.depth,
      orderIndex: orderIndex ?? this.orderIndex,
      semanticType: semanticType ?? this.semanticType,
      createdAt: createdAt,
    );
  }
}
