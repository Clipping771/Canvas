import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinci_board/engines/logic/components/component_registry.dart';
import 'package:vinci_board/engines/logic/models/circuit_component.dart';

class StrokeRenderCache {
  static final StrokeRenderCache _instance = StrokeRenderCache._internal();
  factory StrokeRenderCache() => _instance;
  StrokeRenderCache._internal();

  // LRU cache or unbounded cache for precomputed objects
  final Map<String, TextPainter> _textPainters = {};
  final Map<String, dynamic> _parsedJson = {};
  final Map<String, CircuitComponent> _circuitComponents = {};
  final Map<String, Rect> _boundsCache = {};

  String _currentFont = 'Inter';
  double _currentFontSize = 18.0;

  void setCurrentFont(String font) {
    if (_currentFont != font) {
      _currentFont = font;
      _textPainters.clear();
      _boundsCache.clear();
    }
  }

  void setCurrentFontSize(double size) {
    if (_currentFontSize != size) {
      _currentFontSize = size;
      _textPainters.clear();
      _boundsCache.clear();
    }
  }

  TextPainter? getTextPainter(Stroke stroke) {
    if (stroke.text == null) return null;
    final key = '${stroke.id}_${stroke.version}_text';
    if (_textPainters.containsKey(key)) return _textPainters[key];

    final isUserText =
        stroke.toolType == ToolType.text &&
        stroke.customMetadata?['isAiGenerated'] != true;
    final hasBengali = stroke.text!.codeUnits.any(
      (c) => c >= 0x0980 && c <= 0x09FF,
    );

    // Scale user text size based on the ratio between current global setting and the standard default 18
    final sizeRatio = _currentFontSize / 18.0;
    final double renderedSize = isUserText
        ? (stroke.size * sizeRatio)
        : stroke.size;

    final baseStyle = TextStyle(
      color: stroke.color,
      fontSize: renderedSize,
      height: 1.5,
      fontFamilyFallback: const ['NotoColorEmoji', 'NotoSans'],
    );

    TextStyle textStyle;
    try {
      textStyle = isUserText
          ? (hasBengali
                ? GoogleFonts.galada(textStyle: baseStyle)
                : GoogleFonts.getFont(_currentFont, textStyle: baseStyle))
          : (hasBengali
                ? GoogleFonts.galada(textStyle: baseStyle)
                : GoogleFonts.nanumPenScript(textStyle: baseStyle));
    } catch (_) {
      textStyle = baseStyle;
    }

    final textSpan = TextSpan(text: stroke.text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: stroke.size * 30.0);

    _textPainters[key] = textPainter;
    return textPainter;
  }

  dynamic getParsedJson(Stroke stroke) {
    if (stroke.text == null) return null;
    final key = '${stroke.id}_${stroke.version}_json';
    if (_parsedJson.containsKey(key)) return _parsedJson[key];
    try {
      final json = jsonDecode(stroke.text!);
      _parsedJson[key] = json;
      return json;
    } catch (_) {
      _parsedJson[key] = null;
      return null;
    }
  }

  CircuitComponent? getCircuitComponent(Stroke stroke) {
    final key = '${stroke.id}_${stroke.version}_circuit';
    if (_circuitComponents.containsKey(key)) return _circuitComponents[key];

    final comp = ComponentRegistry().createComponent(stroke);
    if (comp != null) {
      _circuitComponents[key] = comp;
    }
    return comp;
  }

  Rect getBounds(Stroke stroke) {
    final key = '${stroke.id}_${stroke.version}_bounds';
    if (_boundsCache.containsKey(key)) return _boundsCache[key]!;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var p in stroke.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    Rect bounds = stroke.points.isEmpty
        ? Rect.zero
        : Rect.fromLTRB(minX, minY, maxX, maxY);

    if (stroke.points.isNotEmpty) {
      if (stroke.text != null && stroke.toolType != ToolType.widget) {
        final tp = getTextPainter(stroke);
        if (tp != null) {
          bounds = bounds.expandToInclude(
            Rect.fromLTWH(
              stroke.points.first.dx,
              stroke.points.first.dy,
              tp.width,
              tp.height,
            ),
          );
        }
      } else if (stroke.decodedImage != null) {
        final w = stroke.decodedImage!.width.toDouble() * stroke.size;
        final h = stroke.decodedImage!.height.toDouble() * stroke.size;
        bounds = bounds.expandToInclude(
          Rect.fromLTWH(stroke.points.first.dx, stroke.points.first.dy, w, h),
        );
      } else if (stroke.toolType == ToolType.widget) {
        final comp = getCircuitComponent(stroke);
        if (comp != null) {
          bounds = bounds.expandToInclude(
            Rect.fromLTWH(
              stroke.points.first.dx,
              stroke.points.first.dy,
              120,
              80,
            ),
          );
        } else {
          // fallback for weather widget etc
          bounds = bounds.expandToInclude(
            Rect.fromLTWH(
              stroke.points.first.dx,
              stroke.points.first.dy,
              250,
              120,
            ),
          );
        }
      }
    }

    _boundsCache[key] = bounds;
    return bounds;
  }

  void invalidate(String strokeId) {
    _textPainters.removeWhere((k, v) => k.startsWith(strokeId));
    _parsedJson.removeWhere((k, v) => k.startsWith(strokeId));
    _circuitComponents.removeWhere((k, v) => k.startsWith(strokeId));
    _boundsCache.removeWhere((k, v) => k.startsWith(strokeId));
  }

  void clear() {
    _textPainters.clear();
    _parsedJson.clear();
    _circuitComponents.clear();
    _boundsCache.clear();
  }
}
