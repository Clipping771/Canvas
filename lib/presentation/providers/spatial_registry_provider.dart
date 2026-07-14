import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/models/spatial_node.dart';
import 'package:vinci_board/core/canvas/layout_memory.dart';
import 'package:vinci_board/core/canvas/spatial_layout_engine.dart';

class SpatialRegistryState {
  final Map<String, SpatialNode> nodes;
  final GlobalLayoutMemory memory;
  final SpatialLayoutEngine layoutEngine;

  SpatialRegistryState({
    required this.nodes,
    required this.memory,
    required this.layoutEngine,
  });
}

class SpatialRegistryNotifier extends Notifier<SpatialRegistryState> {
  @override
  SpatialRegistryState build() {
    final mem = GlobalLayoutMemory();
    return SpatialRegistryState(
      nodes: {},
      memory: mem,
      layoutEngine: SpatialLayoutEngine(mem),
    );
  }

  void registerNode(SpatialNode node) {
    state.nodes[node.groupId] = node;
    state.memory.recordNode(node);
    state = SpatialRegistryState(
      nodes: Map.from(state.nodes),
      memory: state.memory,
      layoutEngine: state.layoutEngine,
    );
  }

  SpatialNode? getNode(String groupId) {
    return state.nodes[groupId];
  }

  Rect? getParentBounds(String? parentId) {
    if (parentId == null) return null;
    return state.nodes[parentId]?.bounds;
  }

  // A cooldown mechanism to prevent infinite oscillation
  bool _convergenceLock = false;

  void lockConvergence(Duration duration) {
    _convergenceLock = true;
    Future.delayed(duration, () {
      _convergenceLock = false;
    });
  }

  bool get isLocked => _convergenceLock;
}

final spatialRegistryProvider =
    NotifierProvider<SpatialRegistryNotifier, SpatialRegistryState>(() {
      return SpatialRegistryNotifier();
    });
