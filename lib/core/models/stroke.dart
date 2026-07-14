import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/chemistry/chemistry_service.dart';
import 'package:vinci_board/core/canvas/stroke_render_cache.dart';

const _uuid = Uuid();

class Stroke {
  final String id;
  final String? groupId;
  final String? name;
  final List<Offset> points;
  final Color color;
  final double size;
  final double rotation;
  final ToolType toolType;
  final String? text;
  final Uint8List? imageBytes;
  ui.Image? decodedImage;
  final bool isFilled;

  final bool isLocked;

  // Canvas Object Model Metadata
  final String? semanticMeaning;
  final bool physicsEnabled;
  final Map<String, dynamic>? customMetadata;
  final int version;
  final double? animationProgress;
  final String? animationType;
  final Offset? velocity;

  // Chemistry — vector rendering (no raster PNG)
  final String? smiles; // persisted: formula/name used to fetch molecule
  ChemMolecule?
  chemMolecule; // transient: re-fetched from ChemistryService after load

  Stroke({
    String? id,
    this.groupId,
    this.name,
    required this.points,
    required this.color,
    required this.size,
    this.rotation = 0.0,
    required this.toolType,
    this.text,
    this.imageBytes,
    this.decodedImage,
    this.isFilled = false,
    this.isLocked = false,
    this.semanticMeaning,
    this.physicsEnabled = false,
    this.customMetadata,
    this.version = 1,
    this.animationProgress,
    this.animationType,
    this.velocity,
    this.smiles,
    this.chemMolecule,
  }) : id = id ?? _uuid.v4();

  // ─────────────────────────────────────────────────────────
  // bounds
  // ─────────────────────────────────────────────────────────
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    return StrokeRenderCache().getBounds(this);
  }

  // ─────────────────────────────────────────────────────────
  // path (cached)
  // ─────────────────────────────────────────────────────────
  Path? _cachedPath;
  Path get path {
    // Note: _cachedPath assumes Stroke points are immutable after creation.
    // Stroke uses copyWith to create new instances which resets _cachedPath.
    // If points are mutated in-place, this cache will become stale.
    if (_cachedPath != null) return _cachedPath!;
    _cachedPath = Path();
    if (points.isNotEmpty) {
      _cachedPath!.moveTo(points.first.dx, points.first.dy);
      final jumpIndices = customMetadata?['jumpIndices'] != null
          ? List<int>.from(customMetadata!['jumpIndices'])
          : <int>[];
      for (int i = 1; i < points.length; i++) {
        if (jumpIndices.contains(i)) {
          _cachedPath!.moveTo(points[i].dx, points[i].dy);
        } else {
          _cachedPath!.lineTo(points[i].dx, points[i].dy);
        }
      }
      if (isFilled) _cachedPath!.close();
    }
    return _cachedPath!;
  }

  // ─────────────────────────────────────────────────────────
  // copyWith
  // ─────────────────────────────────────────────────────────
  Stroke copyWith({
    String? id,
    String? groupId,
    String? name,
    List<Offset>? points,
    Color? color,
    double? size,
    double? rotation,
    ToolType? toolType,
    String? text,
    Uint8List? imageBytes,
    ui.Image? decodedImage,
    bool? isFilled,
    bool? isLocked,
    String? semanticMeaning,
    bool? physicsEnabled,
    Map<String, dynamic>? customMetadata,
    int? version,
    double? animationProgress,
    String? animationType,
    Offset? velocity,
    String? smiles,
    ChemMolecule? chemMolecule,
    bool clearGroupId = false,
    bool clearName = false,
    bool clearAnimationType = false,
  }) {
    return Stroke(
      id: id ?? this.id,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      name: clearName ? null : (name ?? this.name),
      points: points ?? List.from(this.points),
      color: color ?? this.color,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      toolType: toolType ?? this.toolType,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      decodedImage: decodedImage ?? this.decodedImage,
      isFilled: isFilled ?? this.isFilled,
      isLocked: isLocked ?? this.isLocked,
      semanticMeaning: semanticMeaning ?? this.semanticMeaning,
      physicsEnabled: physicsEnabled ?? this.physicsEnabled,
      customMetadata: customMetadata ?? this.customMetadata,
      version: version ?? this.version,
      animationProgress: animationProgress ?? this.animationProgress,
      animationType: clearAnimationType
          ? null
          : (animationType ?? this.animationType),
      velocity: velocity ?? this.velocity,
      smiles: smiles ?? this.smiles,
      chemMolecule: chemMolecule ?? this.chemMolecule,
    );
  }

  // ─────────────────────────────────────────────────────────
  // serialization
  // ─────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'name': name,
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'color': color.toARGB32(),
    'size': size,
    'rotation': rotation,
    'toolType': toolType.toString(),
    'text': text,
    'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
    'isFilled': isFilled,
    'semanticMeaning': semanticMeaning,
    'physicsEnabled': physicsEnabled,
    'customMetadata': customMetadata,
    'version': version,
    'animationProgress': animationProgress,
    'animationType': animationType,
    'velocity': velocity != null
        ? {'dx': velocity!.dx, 'dy': velocity!.dy}
        : null,
    'smiles': smiles, // persisted — re-fetched client-side after load
  };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
    id: json['id'] as String?,
    groupId: json['groupId'] as String?,
    name: json['name'] as String?,
    points: (json['points'] as List)
        .map(
          (p) =>
              Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()),
        )
        .toList(),
    color: Color(json['color'] as int),
    size: (json['size'] as num).toDouble(),
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    toolType: ToolType.values.firstWhere(
      (e) => e.toString() == json['toolType'],
      orElse: () => ToolType.pen,
    ),
    text: json['text'] as String?,
    imageBytes: json['imageBytes'] != null
        ? base64Decode(json['imageBytes'] as String)
        : null,
    isFilled: json['isFilled'] as bool? ?? false,
    semanticMeaning: json['semanticMeaning'] as String?,
    physicsEnabled: json['physicsEnabled'] as bool? ?? false,
    customMetadata: json['customMetadata'] as Map<String, dynamic>?,
    version: json['version'] as int? ?? 1,
    smiles: json['smiles'] as String?,
    // chemMolecule is transient — canvas_widget re-fetches after load
  );
}
