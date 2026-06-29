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
  }) : id = id ?? _uuid.v4();

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;

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
      final lines = text!.split('\n');
      final maxLineLength = lines
          .map((l) => l.length)
          .reduce((a, b) => a > b ? a : b);
      final width = size * maxLineLength * 0.7;
      final height = size * 1.5 * lines.length;

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
      for (int i = 1; i < points.length; i++) {
        _cachedPath!.lineTo(points[i].dx, points[i].dy);
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
    );
  }
}
