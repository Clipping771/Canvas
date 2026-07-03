import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'tool_type.dart';

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

  // --- Canvas Object Model Metadata ---
  final String? semanticMeaning; // AI-assigned semantic tags
  final bool physicsEnabled; // Flags if this object interacts with physics engine
  final Map<String, dynamic>? customMetadata; // Open-ended state/sync tracking
  final int version; // Event versioning for conflict resolution

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
    this.semanticMeaning,
    this.physicsEnabled = false,
    this.customMetadata,
    this.version = 1,
  }) : id = id ?? _uuid.v4();

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;

    if (toolType == ToolType.widget) {
      // Hardcoded approximate bounds for widgets like weather to prevent overlaps
      return Rect.fromLTWH(points.first.dx, points.first.dy, 400, 250);
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    if (decodedImage != null) {
      final width = decodedImage!.width.toDouble() * size;
      final height = decodedImage!.height.toDouble() * size;

      if (rotation == 0.0) {
        return Rect.fromLTWH(points.first.dx, points.first.dy, width, height);
      }

      final double cosR = math.cos(rotation);
      final double sinR = math.sin(rotation);

      final origin = points.first;
      final corners = [
        origin,
        Offset(origin.dx + width * cosR, origin.dy + width * sinR),
        Offset(origin.dx - height * sinR, origin.dy + height * cosR),
        Offset(
          origin.dx + width * cosR - height * sinR,
          origin.dy + width * sinR + height * cosR,
        ),
      ];

      for (var c in corners) {
        if (c.dx < minX) minX = c.dx;
        if (c.dy < minY) minY = c.dy;
        if (c.dx > maxX) maxX = c.dx;
        if (c.dy > maxY) maxY = c.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    } else if (text != null) {
      int totalEstimatedLines = 0;
      double estimatedMaxWidth = 0.0;
      final lines = text!.split('\n');
      final wrapWidthChars = 50.0; // TextPainter wraps at stroke.size * 30.0, which is roughly 50-60 characters
      for (var l in lines) {
         int wrapCount = (l.length / wrapWidthChars).ceil();
         if (wrapCount == 0) wrapCount = 1;
         totalEstimatedLines += wrapCount;
         
         double lineWidth = l.length > wrapWidthChars ? wrapWidthChars * size * 0.6 : l.length * size * 0.6;
         if (lineWidth > estimatedMaxWidth) estimatedMaxWidth = lineWidth;
      }
      final width = estimatedMaxWidth;
      final height = size * 1.5 * totalEstimatedLines;

      if (rotation == 0.0) {
        return Rect.fromLTWH(points.first.dx, points.first.dy, width, height);
      }

      final double cosR = math.cos(rotation);
      final double sinR = math.sin(rotation);

      final origin = points.first;
      final corners = [
        origin,
        Offset(origin.dx + width * cosR, origin.dy + width * sinR),
        Offset(origin.dx - height * sinR, origin.dy + height * cosR),
        Offset(
          origin.dx + width * cosR - height * sinR,
          origin.dy + width * sinR + height * cosR,
        ),
      ];

      for (var c in corners) {
        if (c.dx < minX) minX = c.dx;
        if (c.dy < minY) minY = c.dy;
        if (c.dx > maxX) maxX = c.dx;
        if (c.dy > maxY) maxY = c.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    } else {
      for (var p in points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
  }

  Path? _cachedPath;
  Path get path {
    if (_cachedPath != null) return _cachedPath!;
    _cachedPath = Path();
    if (points.isNotEmpty) {
      _cachedPath!.moveTo(points.first.dx, points.first.dy);
      
      List<int> jumpIndices = [];
      if (customMetadata != null && customMetadata!['jumpIndices'] != null) {
        jumpIndices = List<int>.from(customMetadata!['jumpIndices']);
      }
      
      for (int i = 1; i < points.length; i++) {
        if (jumpIndices.contains(i)) {
          _cachedPath!.moveTo(points[i].dx, points[i].dy);
        } else {
          _cachedPath!.lineTo(points[i].dx, points[i].dy);
        }
      }
    }
    return _cachedPath!;
  }

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
    String? semanticMeaning,
    bool? physicsEnabled,
    Map<String, dynamic>? customMetadata,
    int? version,
    bool clearGroupId = false,
    bool clearName = false,
  }) {
    return Stroke(
      id: id ?? this.id,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      name: clearName ? null : (name ?? this.name),
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      toolType: toolType ?? this.toolType,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      decodedImage: decodedImage ?? this.decodedImage,
      isFilled: isFilled ?? this.isFilled,
      semanticMeaning: semanticMeaning ?? this.semanticMeaning,
      physicsEnabled: physicsEnabled ?? this.physicsEnabled,
      customMetadata: customMetadata ?? this.customMetadata,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.value,
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
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      id: json['id'] as String?,
      groupId: json['groupId'] as String?,
      name: json['name'] as String?,
      points: (json['points'] as List)
          .map((p) => Offset(p['dx'], p['dy']))
          .toList(),
      color: Color(json['color']),
      size: json['size'],
      rotation: json['rotation'] ?? 0.0,
      toolType: ToolType.values.firstWhere(
        (e) => e.toString() == json['toolType'],
        orElse: () => ToolType.pen,
      ),
      text: json['text'],
      imageBytes: json['imageBytes'] != null
          ? base64Decode(json['imageBytes'])
          : null,
      isFilled: json['isFilled'] ?? false,
      semanticMeaning: json['semanticMeaning'] as String?,
      physicsEnabled: json['physicsEnabled'] ?? false,
      customMetadata: json['customMetadata'] as Map<String, dynamic>?,
      version: json['version'] ?? 1,
    );
  }
}
