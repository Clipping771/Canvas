import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/utils/clustering.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/presentation/providers/settings_provider.dart';
import 'package:vinci_board/adapters/ai/ai_agent_service.dart';
import 'package:vinci_board/core/canvas/canvas_exporter.dart';
import 'package:vinci_board/engines/memory/memory_service.dart';
import 'package:vinci_board/adapters/export/plantuml_service.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/cognitive/cognitive_runtime.dart';
import 'package:vinci_board/engines/cognitive/avatar_engine.dart';
import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';
import 'package:vinci_board/core/canvas/semantic_camera.dart';
import 'package:vinci_board/adapters/ai/ai_stroke_generator.dart';
import 'package:vinci_board/engines/chemistry/chemistry_service.dart';
import 'package:vinci_board/core/utils/sketch_templates.dart';
import 'package:vinci_board/presentation/providers/spatial_registry_provider.dart';
import 'package:vinci_board/core/models/spatial_node.dart';
import 'package:string_similarity/string_similarity.dart';

class AiExecutionController {
  final Ref ref;
  bool _cancelRequested = false;
  final EventBus _eventBus = EventBus();

  // Typewriter animation state
  String _targetMessageText = '';
  String _currentMessageText = '';
  Timer? _typewriterTimer;
  String? _activeStreamStrokeId;
  DrawingNotifier? _activeDrawingNotifier;
  bool _streamDone = false;
  
  AiExecutionController(this.ref);

  void _logDebug(String msg) {
    try {
      final file = File(r'C:\Users\kaush\.gemini\antigravity-ide\scratch\ai_log.txt');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('${DateTime.now().toIso8601String()}: $msg\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  void cancel() {
    _cancelRequested = true;
    _logDebug('cancel() requested. Canceling typewriter timer.');
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
    AiAgentService.cancelRequest();
  }

  void _startTypewriter(String streamStrokeId, DrawingNotifier drawingNotifier) {
    _typewriterTimer?.cancel();
    _activeStreamStrokeId = streamStrokeId;
    _activeDrawingNotifier = drawingNotifier;
    _currentMessageText = '';
    _streamDone = false;
    _logDebug('Typewriter started for stroke: $streamStrokeId');
    
    int lastLoggedTargetLength = -1;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_activeStreamStrokeId == null || _activeDrawingNotifier == null || _cancelRequested) {
        _logDebug('Typewriter timer cancelled. _activeStreamStrokeId: $_activeStreamStrokeId, _activeDrawingNotifier: $_activeDrawingNotifier, _cancelRequested: $_cancelRequested');
        timer.cancel();
        return;
      }
      
      final diff = _targetMessageText.length - _currentMessageText.length;
      if (diff <= 0) {
        if (_streamDone) {
          _logDebug('Typewriter caught up and stream is done. Finalizing...');
          timer.cancel();
          _finalizeTypewriter();
        }
        return;
      }
      
      if (_targetMessageText.length != lastLoggedTargetLength) {
        lastLoggedTargetLength = _targetMessageText.length;
        _logDebug('Typewriter processing: targetLength=${_targetMessageText.length}, currentLength=${_currentMessageText.length}');
      }
      
      // Adaptive speed: add characters faster if we fall behind the stream
      int charsToAdd = 2; // Increased base speed
      if (diff > 60) {
        charsToAdd = 10;
      } else if (diff > 25) {
        charsToAdd = 5;
      }
      
      final nextLength = math.min(_currentMessageText.length + charsToAdd, _targetMessageText.length);
      _currentMessageText = _targetMessageText.substring(0, nextLength);
      
      _activeDrawingNotifier!.updateStrokeByIdSilent(
        _activeStreamStrokeId!,
        (s) => s.copyWith(
          text: _currentMessageText,
          color: Colors.blue.shade900,
          version: s.version + 1,
        ),
      );
    });
  }

  void _finalizeTypewriter() {
    _logDebug('Typewriter finalizing: targetTextLength=${_targetMessageText.length}');
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
    if (_activeStreamStrokeId != null && _activeDrawingNotifier != null) {
      final finalText = _unescapeJsonString(_targetMessageText);
      if (finalText.trim().isEmpty) {
        _logDebug('Finalizing: target text is empty, deleting stroke: $_activeStreamStrokeId');
        _activeDrawingNotifier!.updateStrokeById(_activeStreamStrokeId!, (s) => s.copyWith(isLocked: false), force: true);
        _activeDrawingNotifier!.deleteStroke(_activeStreamStrokeId!);
      } else {
        _logDebug('Finalizing: setting final text (length=${finalText.length}) on stroke: $_activeStreamStrokeId');
        _activeDrawingNotifier!.updateStrokeById(
          _activeStreamStrokeId!,
          (s) => s.copyWith(
            text: finalText,
            color: Colors.black,
            isLocked: false,
            version: s.version + 1,
          ),
          force: true,
        );
      }
    }
    _activeStreamStrokeId = null;
    _activeDrawingNotifier = null;
  }

  Future<void> askAi({
    required String prompt,
    required Offset promptCanvasPosition,
    required Size screenSize,
    required Matrix4 canvasTransform,
    String? promptStrokeId,
  }) async {
    _cancelRequested = false;
    final drawingNotifier = ref.read(drawingProvider.notifier);
    final settings = ref.read(settingsProvider);
    final provider = settings.selectedProvider;
    final modelId = settings.selectedModel;
    final apiKey = settings.apiKeys[provider] ?? '';

    if (apiKey.isEmpty) {
      drawingNotifier.placeText("AI Error: Please enter an API key for ${provider.name} in Settings.", Offset(promptCanvasPosition.dx, promptCanvasPosition.dy + 100));
      return;
    }

    drawingNotifier.setAiStatus('Thinking', target: promptCanvasPosition);
    CognitiveRuntime().avatarEngine.setState(AvatarState.thinking);
    CognitiveRuntime().avatarEngine.moveTo(promptCanvasPosition);

    try {
      final strokes = ref.read(drawingProvider).strokes;
      final pixelRatio = 0.5;

      final imageBytes = await CanvasExporter.exportStrokesToImage(
        strokes,
        canvasSize: screenSize,
        transform: canvasTransform,
        pixelRatio: pixelRatio,
      );

      final strokeDataList = strokes.map((s) => StrokeData(
         id: s.id,
         text: s.text,
         hasImage: s.decodedImage != null,
         bounds: [s.bounds.left, s.bounds.top, s.bounds.right, s.bounds.bottom],
         firstPoint: s.points.isNotEmpty ? [s.points.first.dx, s.points.first.dy] : [0.0, 0.0],
      )).toList();

      final canvasObjects = await compute(performStrokesClustering, strokeDataList);

      double bottomY = promptCanvasPosition.dy + 60;
      if (promptStrokeId != null) {
        try {
          final promptStroke = strokes.firstWhere((s) => s.id == promptStrokeId);
          bottomY = promptStroke.bounds.bottom + 30;
        } catch (_) {}
      }

      final responsePosition = Offset(promptCanvasPosition.dx, bottomY);
      final streamStrokeId = drawingNotifier.placeText("Thinking...", responsePosition);
      drawingNotifier.updateStrokeById(
        streamStrokeId,
        (s) => s.copyWith(
          isLocked: true,
          color: Colors.grey,
          customMetadata: const {'isAiGenerated': true},
        ),
        force: true,
      );

      try {
        final file = File(r'C:\Users\kaush\.gemini\antigravity-ide\scratch\ai_log.txt');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('--- START LOG ---\n', flush: true);
      } catch (_) {}

      _logDebug('askAi started: prompt="$prompt"');

      String response = '';
      final Completer<void> completer = Completer<void>();

      _targetMessageText = '';
      _currentMessageText = '';
      _streamDone = false;
      _startTypewriter(streamStrokeId, drawingNotifier);

      final relativePrompt = "$prompt\n\n[System Context: The user's prompt is written on the canvas at (${promptCanvasPosition.dx.toStringAsFixed(1)}, ${promptCanvasPosition.dy.toStringAsFixed(1)}). The bottom bounds of their prompt is at y = ${bottomY.toStringAsFixed(1)}. You MUST place all your generated text, drawings, and widgets ('ops') BELOW this prompt, starting at y = ${(bottomY + 15).toStringAsFixed(1)}.]";

      final stream = AiAgentService.askAgentStream(
        imageBytes: imageBytes ?? [],
        prompt: relativePrompt,
        provider: provider,
        apiKey: apiKey,
        modelId: modelId,
        chatHistory: [],
        canvasObjects: canvasObjects,
      );

      bool isWorking = false;

      StreamSubscription<String>? subscription;
      _logDebug('Subscribing to stream...');
      subscription = stream.listen(
        (chunk) {
          try {
            if (_cancelRequested) {
              _logDebug('Stream onData: cancel requested, canceling subscription.');
              subscription?.cancel();
              _typewriterTimer?.cancel();
              _typewriterTimer = null;
              if (!completer.isCompleted) completer.complete();
              return;
            }
            if (!isWorking) {
              isWorking = true;
              _logDebug('Stream onData: setting status to Working...');
              drawingNotifier.setAiStatus('Working', target: promptCanvasPosition);
            }
            response = chunk;
            _logDebug('Stream onData chunk received (length=${chunk.length})');
            
            final extracted = _extractMessageFromPartialJson(chunk);
            if (extracted.trim().isNotEmpty) {
              _targetMessageText = _unescapeJsonString(extracted);
            }
          } catch (e, st) {
            _logDebug('ERROR in stream callback: $e\n$st');
            _targetMessageText = "Callback Error: $e";
          }
        },
        onError: (err) {
          _logDebug('Stream onError: $err');
          response = "AI Error: $err";
          _streamDone = true;
          _targetMessageText = response;
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          _logDebug('Stream onDone');
          _streamDone = true;
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;

      if (_cancelRequested) {
        _typewriterTimer?.cancel();
        _typewriterTimer = null;
        drawingNotifier.updateStrokeById(streamStrokeId, (s) => s.copyWith(text: "Generation stopped by user.", color: Colors.grey, isLocked: false, version: s.version + 1), force: true);
        return;
      }

      final finalExtracted = _unescapeJsonString(_extractMessageFromPartialJson(response));

      try {
        String cleanJson = response.trim();
        if (cleanJson.startsWith('```')) {
          final lines = cleanJson.split('\n');
          if (lines.isNotEmpty && lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
          cleanJson = lines.join('\n').trim();
        }
        final data = jsonDecode(cleanJson);
        final ops = data['ops'] as List?;
        if (ops != null && ops.isNotEmpty) {
          await _executeAiActions(
            ops,
            canvasTransform: canvasTransform,
            drawingNotifier: drawingNotifier,
            aiMessage: finalExtracted,
            targetTopLeft: responsePosition,
          );
        }
      } catch (e) {
        debugPrint("AI JSON execution error: $e");
      }

    } catch (e, st) {
      debugPrint("Spatial AI Error: $e\n$st");
      drawingNotifier.placeText("AI Error: $e", Offset(promptCanvasPosition.dx, promptCanvasPosition.dy + 60));
    } finally {
      drawingNotifier.setAiStatus(null);
      CognitiveRuntime().avatarEngine.setState(AvatarState.idle);
    }
  }

  String _extractMessageFromPartialJson(String jsonStr) {
    final match = RegExp(r'"(?:message|rationale)"\s*:\s*"').firstMatch(jsonStr);
    if (match == null) {
      if (!jsonStr.trim().startsWith('{') && jsonStr.trim().isNotEmpty) {
        return jsonStr;
      }
      return "";
    }
    final startIndex = match.end;
    int endIndex = startIndex;
    bool escaped = false;
    while (endIndex < jsonStr.length) {
      final char = jsonStr[endIndex];
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        return jsonStr.substring(startIndex, endIndex);
      }
      endIndex++;
    }
    return jsonStr.substring(startIndex);
  }

  String _unescapeJsonString(String input) {
    try {
      String clean = input;
      if (clean.endsWith('\\')) {
        clean = clean.substring(0, clean.length - 1);
      }
      return jsonDecode('"$clean"');
    } catch (_) {
      return input
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', '\t')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\')
          .replaceAll(r'\/', '/');
    }
  }

  Future<void> _executeAiActions(
    List actions, {
    required Matrix4 canvasTransform,
    required DrawingNotifier drawingNotifier,
    Offset? targetTopLeft,
    String? aiMessage,
  }) async {
    final newStrokes = <Stroke>[];
    int objectsAdded = 0;
    int objectsUpdated = 0;
    int objectsRemoved = 0;
    final unrecognized = <String>[];
    String? aiFocusTargetId;

    // Calculate bounding box of all image-space shapes/widgets to offset them as a group relative to prompt
    double? minX, minY, maxX, maxY;
    for (var action in actions) {
      if (action is! Map) continue;
      final type = action['action'] as String?;
      if (type == null) continue;

      List<Offset> points = [];
      if (type == 'draw_rect') {
        final rectData = action['rect'] as List?;
        if (rectData != null && rectData.length >= 4) {
          final x = rectData[0].toDouble();
          final y = rectData[1].toDouble();
          final w = rectData[2].toDouble();
          final h = rectData[3].toDouble();
          if (x.abs() <= 2500 && y.abs() <= 2500) {
            points.add(Offset(x, y));
            points.add(Offset(x + w, y + h));
          }
        }
      } else if (type == 'draw_circle') {
        final center = action['center'] as List?;
        final r = (action['radius'] as num?)?.toDouble() ?? 50.0;
        if (center != null && center.length >= 2) {
          final cx = center[0].toDouble();
          final cy = center[1].toDouble();
          if (cx.abs() <= 2500 && cy.abs() <= 2500) {
            points.add(Offset(cx - r, cy - r));
            points.add(Offset(cx + r, cy + r));
          }
        }
      } else if (type == 'draw_ellipse') {
        final center = action['center'] as List?;
        final rx = (action['rx'] as num?)?.toDouble() ?? 50.0;
        final ry = (action['ry'] as num?)?.toDouble() ?? 30.0;
        if (center != null && center.length >= 2) {
          final cx = center[0].toDouble();
          final cy = center[1].toDouble();
          if (cx.abs() <= 2500 && cy.abs() <= 2500) {
            points.add(Offset(cx - rx, cy - ry));
            points.add(Offset(cx + rx, cy + ry));
          }
        }
      } else if (type == 'draw_polygon' || type == 'draw_wire') {
        final pts = action['points'] as List?;
        if (pts != null) {
          for (var pt in pts) {
            if (pt is List && pt.length >= 2) {
              final x = pt[0].toDouble();
              final y = pt[1].toDouble();
              if (x.abs() <= 2500 && y.abs() <= 2500) {
                points.add(Offset(x, y));
              }
            }
          }
        }
      } else if (type == 'draw_line') {
        final start = action['start'] as List?;
        final end = action['end'] as List?;
        if (start != null && start.length >= 2 && end != null && end.length >= 2) {
          final x1 = start[0].toDouble();
          final y1 = start[1].toDouble();
          final x2 = end[0].toDouble();
          final y2 = end[1].toDouble();
          if (x1.abs() <= 2500 && y1.abs() <= 2500) {
            points.add(Offset(x1, y1));
            points.add(Offset(x2, y2));
          }
        }
      } else if (type == 'draw_latex' || type == 'draw_text' || type == 'insert_chemistry' || type == 'insert_widget') {
        final pos = action['position'] as List?;
        if (pos != null && pos.length >= 2) {
          final x = pos[0].toDouble();
          final y = pos[1].toDouble();
          if (x.abs() <= 2500 && y.abs() <= 2500) {
            points.add(Offset(x, y));
          }
        }
      }

      for (var pt in points) {
        if (minX == null || pt.dx < minX) minX = pt.dx;
        if (minY == null || pt.dy < minY) minY = pt.dy;
        if (maxX == null || pt.dx > maxX) maxX = pt.dx;
        if (maxY == null || pt.dy > maxY) maxY = pt.dy;
      }
    }

    final transform = canvasTransform;
    final Matrix4 inverse = Matrix4.copy(transform)..invert();

    Offset mapPoint(double x, double y) {
      // If the coordinate is already in canvas space (which is centered around 50000),
      // we do not need to transform it from image space to canvas space.
      if (x.abs() > 2500 || y.abs() > 2500) {
        return Offset(x, y);
      }

      if (targetTopLeft != null && minX != null && minY != null) {
        final scale = inverse.getMaxScaleOnAxis();
        return Offset(
          targetTopLeft.dx + (x - minX) * scale,
          (targetTopLeft.dy + 35.0) + (y - minY) * scale,
        );
      }

      // Divide by the same pixelRatio used in CanvasExporter (0.5)
      final scaledX = x / 0.5;
      final scaledY = y / 0.5;
      final point = MatrixUtils.transformPoint(
        inverse,
        Offset(scaledX, scaledY),
      );
      return point;
    }

    double? internalSafeY;
    Offset? lastPlacedPos;
    Offset? lastRequestedPos;

    bool checkCollision(Rect newBounds) {
      final spatialCandidates = drawingNotifier.spatialIndex.queryRect(
        newBounds,
      );
      if (spatialCandidates.isNotEmpty) {
        return true;
      }
      for (var s in newStrokes) {
        if (s.points.isNotEmpty && newBounds.overlaps(s.bounds)) {
          return true;
        }
      }
      return false;
    }

    for (var action in actions) {
      if (_cancelRequested) {
        throw Exception("Cancelled by user");
      }
      if (action is Map) {
        final type = action['action'] ?? action['type'] ?? 'unknown';

        try {
          if (type == 'clear_canvas') {
            drawingNotifier.clear();
            objectsUpdated++; // Prevent fallback
            continue;
          } else if (type == 'update') {
            final targetId = action['targetId']?.toString();
            final targetGroupId = action['targetGroupId']?.toString();
            final patch = action['patch'] is Map
                ? action['patch'] as Map
                : null;
            if (patch != null && (targetId != null || targetGroupId != null)) {
              final colorHex = patch['color']?.toString();
              Color? patchColor;
              if (colorHex != null) {
                try {
                  if (colorHex.startsWith('#')) {
                    patchColor = Color(
                      int.parse(colorHex.substring(1), radix: 16) + 0xFF000000,
                    );
                  } else if (colorHex.startsWith('0x') ||
                      colorHex.startsWith('0X')) {
                    patchColor = Color(
                      int.parse(colorHex.substring(2), radix: 16),
                    );
                  } else {
                    // Fallback for named colors if they hallucinate
                    if (colorHex.toLowerCase() == 'red') {
                      patchColor = Colors.red;
                    } else if (colorHex.toLowerCase() == 'blue')
                      patchColor = Colors.blue;
                    else if (colorHex.toLowerCase() == 'green')
                      patchColor = Colors.green;
                    else if (colorHex.toLowerCase() == 'yellow')
                      patchColor = Colors.yellow;
                    else if (colorHex.toLowerCase() == 'black')
                      patchColor = Colors.black;
                    else if (colorHex.toLowerCase() == 'white')
                      patchColor = Colors.white;
                    else
                      patchColor = Color(int.parse(colorHex));
                  }
                } catch (_) {}
              }
              final isFilled = patch['isFilled'] is bool
                  ? patch['isFilled'] as bool
                  : (patch['isFilled']?.toString().toLowerCase() == 'true');

              Stroke updater(Stroke s) {
                return s.copyWith(color: patchColor, isFilled: isFilled);
              }

              if (targetId != null) {
                objectsUpdated += drawingNotifier.updateStrokeById(
                  targetId,
                  updater,
                );
              } else if (targetGroupId != null) {
                objectsUpdated += drawingNotifier.updateStrokesByGroupId(
                  targetGroupId,
                  updater,
                );
              }
            }
            continue;
          } else if (type == 'remove') {
            final targetId = action['targetId']?.toString();
            final targetGroupId = action['targetGroupId']?.toString();
            if (targetId != null || targetGroupId != null) {
              final ids = <String>[];
              if (targetId != null) ids.add(targetId);
              if (targetGroupId != null) ids.add(targetGroupId);
              objectsRemoved += drawingNotifier.removeStrokesByIds(ids);
            }
            continue;
          } else if (type == 'tag') {
            final ids = action['ids'] is List
                ? (action['ids'] as List).map((e) => e.toString()).toList()
                : null;
            final name = action['name']?.toString();
            if (ids != null && name != null && ids.isNotEmpty) {
              objectsUpdated += drawingNotifier.tagStrokes(ids, name);
            }
            continue;
          } else if (type == 'undo') {
            final count = (action['count'] as num?)?.toInt() ?? 1;
            for (int i = 0; i < count; i++) {
              drawingNotifier.undo();
            }
            continue;
          } else if (type == 'learn_rule') {
            final rule = action['rule'] as String?;
            if (rule != null) {
              await MemoryService.addRule(rule);
              }
            continue;
          } else if (type == 'delete_area' || type == 'erase_rect') {
            final rectData = action['rect'] as List?;
            if (rectData != null && rectData.length >= 4) {
              final p1 = mapPoint(
                rectData[0].toDouble(),
                rectData[1].toDouble(),
              );
              final p2 = mapPoint(
                rectData[0].toDouble() + rectData[2].toDouble(),
                rectData[1].toDouble() + rectData[3].toDouble(),
              );
              final bounds = Rect.fromPoints(p1, p2);
              drawingNotifier.eraseRect(bounds);
            }
            continue;
          } else if (type == 'change_background') {
            final colorHex = action['color']?.toString();
            if (colorHex != null) {
              Color? color;
              try {
                if (colorHex.startsWith('#')) {
                  color = Color(
                    int.parse(colorHex.substring(1), radix: 16) + 0xFF000000,
                  );
                } else {
                  // Fallback for named colors
                  if (colorHex.toLowerCase() == 'red') {
                    color = Colors.red;
                  } else if (colorHex.toLowerCase() == 'blue')
                    color = Colors.blue;
                  else if (colorHex.toLowerCase() == 'green')
                    color = Colors.green;
                  else if (colorHex.toLowerCase() == 'yellow')
                    color = Colors.yellow;
                  else if (colorHex.toLowerCase() == 'black')
                    color = Colors.black;
                  else if (colorHex.toLowerCase() == 'white')
                    color = Colors.white;
                  else
                    color = Color(int.parse(colorHex));
                }
              } catch (_) {}

              if (color != null) {
                drawingNotifier.setCanvasBackgroundColor(color);
                objectsUpdated++; // Prevent fallback
              }
            }
            continue;
          } else if (type == 'trigger_effect') {
            String? effect =
                (action['effect'] ??
                        action['effectName'] ??
                        action['name'] ??
                        action['type'])
                    ?.toString();
            if (effect != null) {
              drawingNotifier.triggerEasterEgg(effect);
              objectsUpdated++; // Prevent fallback
            }
            continue;
          } else if (type == 'insert_uml') {
            final umlStr = action['plantuml']?.toString();
            final posData = action['position'] as List?;
            if (umlStr != null) {
              double rawX = 100.0, rawY = 100.0;
              if (posData != null && posData.length >= 2) {
                rawX = posData[0].toDouble();
                rawY = posData[1].toDouble();
              }
              final p = mapPoint(rawX, rawY);

              final bytes = await PlantUmlService.fetchUmlImage(umlStr);
              if (bytes != null && true) {
                try {
                  // Pre-decode the image so the bounding box is correct instantly
                  final decodedImage = await decodeImageFromList(bytes);
                  newStrokes.add(
                    Stroke(
                      points: [p],
                      color: Colors.transparent,
                      size: 1.0,
                      toolType: ToolType.pan,
                      imageBytes: bytes,
                      decodedImage: decodedImage,
                    ),
                  );
                } catch (e) {
                  throw Exception("Failed to decode UML image: $e");
                }
              } else {
                throw Exception("Failed to fetch UML image from PlantUML API.");
              }
            }
            continue;
          } else if (type == 'focus_area') {
            final rectData = action['rect'] as List?;
            if (rectData != null && rectData.length >= 4) {
              double x = rectData[0].toDouble();
              double y = rectData[1].toDouble();
              double w = rectData[2].toDouble();
              double h = rectData[3].toDouble();
              final p1 = mapPoint(x, y);
              final p2 = mapPoint(x + w, y + h);
              final focusRect = Rect.fromPoints(p1, p2);

              drawingNotifier.setLastAddedBounds(focusRect);
              objectsUpdated++; // Ensure we don't count as fallback

              // Immediately trigger focus without waiting for drawing
              _eventBus.publish(
                BaseEvent.generic(
                  'aiTaskCompleted',
                  payload: {'intent': CameraIntent.hardFocus},
                ),
              );
            }
            continue;
          } else if (type == 'insert_widget') {
            final widgetType = action['type']?.toString();
            final posData = action['position'] as List?;
            if (widgetType != null) {
              double rawX = 100.0, rawY = 100.0;
              if (posData != null && posData.length >= 2) {
                rawX = posData[0].toDouble();
                rawY = posData[1].toDouble();
              }
              final p = mapPoint(rawX, rawY);

              final existingWidgets = ref.read(drawingProvider).strokes.where((
                s,
              ) {
                if (s.toolType != ToolType.widget || s.text == null) {
                  return false;
                }
                try {
                  final j = jsonDecode(s.text!);
                  return j['type'] ==
                      widgetType; // Check if it's the same widget type (e.g. 'weather')
                } catch (_) {
                  return false;
                }
              }).toList();

              if (existingWidgets.isNotEmpty) {
                // If there's an existing widget of this type, we update it by deleting the old one
                // and placing the new one at the exact same position!
                final oldPos = existingWidgets.first.points.first;
                drawingNotifier.eraseStrokes(existingWidgets);

                final stroke = Stroke(
                  points: [oldPos], // Keep the original position!
                  color: Colors.transparent,
                  size: 1.0,
                  toolType: ToolType.widget,
                  text: jsonEncode(action),
                  groupId: 'widget_${DateTime.now().millisecondsSinceEpoch}',
                );
                newStrokes.add(stroke);
              } else {
                // Create completely new widget
                final stroke = Stroke(
                  points: [p],
                  color: Colors.transparent,
                  size: 1.0,
                  toolType: ToolType.widget,
                  text: jsonEncode(action),
                  groupId: 'widget_${DateTime.now().millisecondsSinceEpoch}',
                );
                newStrokes.add(stroke);
              }
            }
            continue;
          } else if (type == 'generate_circuit') {
            final components = action['components'] as List?;
            final wires = action['wires'] as List?;

            if (components != null) {
              for (var c in components) {
                final pos = c['position'] as List;
                final p = mapPoint(pos[0].toDouble(), pos[1].toDouble());
                final id = c['id'] as String;
                final compType = c['type'] as String;

                final stroke = Stroke(
                  id: id,
                  points: [p],
                  color:
                      Colors.transparent, // component handles its own drawing
                  size: 40.0,
                  toolType: ToolType.text,
                  text: compType,
                  groupId: 'circuit_${DateTime.now().millisecondsSinceEpoch}',
                );
                newStrokes.add(stroke);
              }
            }

            if (wires != null) {
              for (var w in wires) {
                final source = w['source'] as String;
                final target = w['target'] as String;

                // split c1_out to sourceId: "c1", pinId: "c1_out"
                final sourceId = source.split('_')[0];
                final targetId = target.split('_')[0];

                final stroke = Stroke(
                  points:
                      [], // engine will generate bezier points automatically based on metadata
                  color: Colors.grey,
                  size: 4.0,
                  toolType: ToolType.wire,
                  customMetadata: {
                    'sourceId': sourceId,
                    'targetId': targetId,
                    'sourcePinId': source,
                    'targetPinId': target,
                  },
                  groupId: 'circuit_${DateTime.now().millisecondsSinceEpoch}',
                );
                newStrokes.add(stroke);
              }
            }
            objectsUpdated++;
            continue;
          } else if (type == 'apply_gravity') {
            final targetGroupId = action['targetGroupId'] as String?;
            final targetIds = action['targetIds'] as List?;

            if (targetIds != null && targetIds.isNotEmpty) {
              drawingNotifier.applyGravityToStrokes(targetIds.cast<String>());
              aiFocusTargetId = targetIds.first;
            } else if (targetGroupId != null) {
              drawingNotifier.applyGravityToGroup(targetGroupId);
            } else {
              // Apply to the most recently added group if no target is specified
              final currentStrokes = ref.read(drawingProvider).strokes;
              if (currentStrokes.isNotEmpty) {
                final lastGroupId = currentStrokes.last.groupId;
                if (lastGroupId != null) {
                  drawingNotifier.applyGravityToGroup(lastGroupId);
                } else {
                  drawingNotifier.applyGravityToStrokes([
                    currentStrokes.last.id,
                  ]);
                }
              }
            }
            objectsUpdated++; // Prevent fallback
            continue;
          } else if (type == 'apply_animation') {
            final targetIds = action['targetIds'] as List?;
            final animationType =
                action['animationType'] as String? ?? 'bounce';

            if (targetIds != null && targetIds.isNotEmpty) {
              drawingNotifier.applyAnimationToStrokes(
                targetIds.cast<String>(),
                animationType,
              );
              aiFocusTargetId = targetIds.first;
            } else {
              final currentStrokes = ref.read(drawingProvider).strokes;
              if (currentStrokes.isNotEmpty) {
                drawingNotifier.applyAnimationToStrokes([
                  currentStrokes.last.id,
                ], animationType);
                aiFocusTargetId = currentStrokes.last.id;
              }
            }
            objectsUpdated++;
            continue;
          } else if (type == 'stop_simulation') {
            drawingNotifier.stopSimulation();
            objectsUpdated++;
            continue;
          }

          final colorStr = action['color']?.toString() ?? '0xFF000000';
          Color color = const Color(0xFF000000);
          try {
            if (colorStr.startsWith('#')) {
              color = Color(
                int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
              );
            } else if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
              color = Color(int.parse(colorStr.substring(2), radix: 16));
            } else {
              // Fallback for named colors
              if (colorStr.toLowerCase() == 'red') {
                color = Colors.red;
              } else if (colorStr.toLowerCase() == 'blue')
                color = Colors.blue;
              else if (colorStr.toLowerCase() == 'green')
                color = Colors.green;
              else if (colorStr.toLowerCase() == 'yellow')
                color = Colors.yellow;
              else if (colorStr.toLowerCase() == 'black')
                color = Colors.black;
              else if (colorStr.toLowerCase() == 'white')
                color = Colors.white;
              else
                color = Color(int.parse(colorStr));
            }
          } catch (_) {}

          // --- ADAPTABILITY LOGIC ---
          final bgColor =
              ref.read(drawingProvider).canvasBackgroundColor ?? Colors.white;
          final bgLum = bgColor.computeLuminance();
          final colorLum = color.computeLuminance();

          // If the AI's chosen color is too similar in brightness to the background, flip it!
          if ((bgLum - colorLum).abs() < 0.25) {
            color = bgLum > 0.5 ? Colors.black : Colors.white;
          }

          // Robustly parse size
          double size = 8.0; // Default to 16.0 / 2.0
          try {
            final rawSize = action['size'];
            if (rawSize is num) {
              size = rawSize.toDouble() / 2.0;
            } else if (rawSize is String) {
              size = (double.tryParse(rawSize) ?? 16.0) / 2.0;
            }
          } catch (_) {}
          final scale = inverse.getMaxScaleOnAxis();
          size = size * scale; // Adjust line thickness relative to canvas zoom
          final shapeFilled =
              (action['isFilled'] ?? action['filled']) as bool? ?? false;
          if (type == 'draw_rect') {
            final rectData = action['rect'] as List?;
            if (rectData == null || rectData.length < 4) continue;
            final p1Raw = mapPoint(
              rectData[0].toDouble(),
              rectData[1].toDouble(),
            );
            final w = rectData[2].toDouble();
            final h = rectData[3].toDouble();

            final p = p1Raw;
            double finalX = p.dx;
            double finalY = p.dy;
            double currentRadius = 0;
            double angle = 0;
            bool hasCollision = true;
            int iterations = 0;

            final overlap =
                action['overlap'] == true || action['allowOverlap'] == true;
            if (overlap) hasCollision = false;

            while (hasCollision && iterations < 100) {
              Rect newBounds = Rect.fromLTWH(
                finalX - 10,
                finalY - 10,
                w + 20,
                h + 20,
              );
              hasCollision = checkCollision(newBounds);

              if (hasCollision) {
                currentRadius += 20;
                angle += 0.5; // spiral out
                finalX = p.dx + currentRadius * math.cos(angle);
                finalY = p.dy + currentRadius * math.sin(angle);
              }
              iterations++;
            }

            newStrokes.add(
              AiStrokeGenerator.generateRect(
                finalX,
                finalY,
                w,
                h,
                color,
                size,
                isFilled: shapeFilled,
              ),
            );
          } else if (type == 'draw_circle') {
            final center = action['center'] as List?;
            if (center == null || center.length < 2) continue;
            final isCanvasSpace = center[0].toDouble().abs() > 2500 || center[1].toDouble().abs() > 2500;
            final p = mapPoint(center[0].toDouble(), center[1].toDouble());
            final radius = isCanvasSpace
                ? (action['radius'] as num).toDouble()
                : ((action['radius'] as num).toDouble() / 2.0) * scale;

            double finalX = p.dx;
            double finalY = p.dy;
            double currentRadius = 0;
            double angle = 0;
            bool hasCollision = true;
            int iterations = 0;

            final overlap =
                action['overlap'] == true || action['allowOverlap'] == true;
            if (overlap) hasCollision = false;

            while (hasCollision && iterations < 100) {
              Rect newBounds = Rect.fromLTWH(
                finalX - radius - 10,
                finalY - radius - 10,
                (radius * 2) + 20,
                (radius * 2) + 20,
              );
              hasCollision = checkCollision(newBounds);

              if (hasCollision) {
                currentRadius += 20;
                angle += 0.5; // spiral out
                finalX = p.dx + currentRadius * math.cos(angle);
                finalY = p.dy + currentRadius * math.sin(angle);
              }
              iterations++;
            }

            newStrokes.add(
              AiStrokeGenerator.generateCircle(
                finalX,
                finalY,
                radius,
                color,
                size,
                isFilled: shapeFilled,
              ),
            );
          } else if (type == 'draw_polygon') {
            final pointsData = action['points'] as List?;
            if (pointsData == null || pointsData.length < 3) continue;
            final mappedPoints = pointsData.map((pt) {
              return mapPoint(
                (pt[0] as num).toDouble(),
                (pt[1] as num).toDouble(),
              );
            }).toList();
            newStrokes.add(
              AiStrokeGenerator.generatePolygon(
                mappedPoints,
                color,
                size,
                isFilled: shapeFilled,
              ),
            );
          } else if (type == 'draw_line') {
            final start = action['start'] as List?;
            final end = action['end'] as List?;
            if (start == null ||
                start.length < 2 ||
                end == null ||
                end.length < 2) {
              continue;
            }
            final p1 = mapPoint(start[0].toDouble(), start[1].toDouble());
            final p2 = mapPoint(end[0].toDouble(), end[1].toDouble());
            newStrokes.add(
              AiStrokeGenerator.generateLine(
                p1.dx,
                p1.dy,
                p2.dx,
                p2.dy,
                color,
                size,
              ),
            );
          } else if (type == 'draw_latex') {
            final text = action['latex'] as String;
            List? pos = action['position'] as List?;
            if (pos == null || pos.length < 2) {
              pos = [100.0, 100.0];
            }

            double rawX = pos[0].toDouble();
            double rawY = pos[1].toDouble();

            if (internalSafeY != null && rawY < internalSafeY) {
              rawY = internalSafeY;
            }
            final linesCount = text.split('\n').length;
            internalSafeY =
                rawY +
                (linesCount * 180) +
                100; // Increased dynamic spacing for tall LaTeX equations

            final p = mapPoint(rawX, rawY);
            final scale = inverse.getMaxScaleOnAxis();

            newStrokes.add(
              Stroke(
                points: [Offset(p.dx, p.dy)],
                color: color,
                size:
                    (size * scale) *
                    3.0, // Make LaTeX math equations highly readable
                toolType: ToolType.latex,
                text: text,
              ),
            );
          } else if (type == 'draw_composite') {
            final parts = action['parts'] as List?;
            final pos = action['position'] as List?;
            final compositeName = action['name'] as String? ?? 'composite';
            final scaleModifier = (action['scale'] as num?)?.toDouble() ?? 1.0;

            if (parts != null && pos != null && pos.length >= 2) {
              double rawX = pos[0].toDouble();
              double rawY = pos[1].toDouble();
              final basePos = mapPoint(rawX, rawY);
              final viewScale = inverse.getMaxScaleOnAxis();
              final overallScale = viewScale * scaleModifier;

              final groupId =
                  '${compositeName}_${DateTime.now().millisecondsSinceEpoch}';

              void parsePartsList(List partsList) {
                for (var part in partsList) {
                  if (part is! Map) continue;
                  final partType = part['type'] as String?;
                  final partColorHex = part['color'] as String?;
                  Color partColor = color; // default to outer color
                  if (partColorHex != null) {
                    try {
                      partColor = Color(
                        int.parse(
                              partColorHex
                                  .replaceFirst('0x', '')
                                  .replaceFirst('#', ''),
                              radix: 16,
                            ) +
                            0xFF000000,
                      );
                    } catch (_) {}
                  }
                  final isFilled = part['isFilled'] as bool? ?? false;

                  if (partType == 'circle') {
                    final cx = (part['cx'] as num?)?.toDouble() ?? 0.0;
                    final cy = (part['cy'] as num?)?.toDouble() ?? 0.0;
                    final r = (part['r'] as num?)?.toDouble() ?? 20.0;
                    final stroke = AiStrokeGenerator.generateCircle(
                      basePos.dx + (cx * overallScale),
                      basePos.dy + (cy * overallScale),
                      r * overallScale,
                      partColor,
                      2.0 * viewScale,
                    );
                    newStrokes.add(
                      stroke.copyWith(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        isFilled: isFilled,
                        semanticMeaning: compositeName,
                      ),
                    );
                  } else if (partType == 'ellipse') {
                    final cx = (part['cx'] as num?)?.toDouble() ?? 0.0;
                    final cy = (part['cy'] as num?)?.toDouble() ?? 0.0;
                    final rx = (part['rx'] as num?)?.toDouble() ?? 30.0;
                    final ry = (part['ry'] as num?)?.toDouble() ?? 20.0;
                    final stroke = AiStrokeGenerator.generateEllipse(
                      basePos.dx + (cx * overallScale),
                      basePos.dy + (cy * overallScale),
                      rx * overallScale,
                      ry * overallScale,
                      partColor,
                      2.0 * viewScale,
                    );
                    newStrokes.add(
                      stroke.copyWith(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        isFilled: isFilled,
                        semanticMeaning: compositeName,
                      ),
                    );
                  } else if (partType == 'rect') {
                    final px = (part['x'] as num?)?.toDouble() ?? 0.0;
                    final py = (part['y'] as num?)?.toDouble() ?? 0.0;
                    final pw = (part['w'] as num?)?.toDouble() ?? 40.0;
                    final ph = (part['h'] as num?)?.toDouble() ?? 40.0;
                    final stroke = AiStrokeGenerator.generateRect(
                      basePos.dx + (px * overallScale),
                      basePos.dy + (py * overallScale),
                      pw * overallScale,
                      ph * overallScale,
                      partColor,
                      2.0 * viewScale,
                    );
                    newStrokes.add(
                      stroke.copyWith(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        isFilled: isFilled,
                        semanticMeaning: compositeName,
                      ),
                    );
                  } else if (partType == 'line') {
                    final x1 = (part['x1'] as num?)?.toDouble() ?? 0.0;
                    final y1 = (part['y1'] as num?)?.toDouble() ?? 0.0;
                    final x2 = (part['x2'] as num?)?.toDouble() ?? 0.0;
                    final y2 = (part['y2'] as num?)?.toDouble() ?? 0.0;
                    newStrokes.add(
                      Stroke(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        semanticMeaning: compositeName,
                        points: [
                          Offset(
                            basePos.dx + (x1 * overallScale),
                            basePos.dy + (y1 * overallScale),
                          ),
                          Offset(
                            basePos.dx + (x2 * overallScale),
                            basePos.dy + (y2 * overallScale),
                          ),
                        ],
                        color: partColor,
                        size: 2.0 * viewScale,
                        toolType: ToolType.pen,
                      ),
                    );
                  } else if (partType == 'bezier_curve') {
                    final p0 = part['p0'] as List? ?? [0, 0];
                    final p1 = part['p1'] as List? ?? [0, 0];
                    final p2 = part['p2'] as List? ?? [0, 0];
                    final p3 = part['p3'] as List? ?? [0, 0];
                    double safeNum(dynamic l, int idx) =>
                        (l is List && l.length > idx && l[idx] != null)
                        ? (l[idx] as num).toDouble()
                        : 0.0;
                    final stroke = AiStrokeGenerator.generateBezierCurve(
                      Offset(
                        basePos.dx + (safeNum(p0, 0) * overallScale),
                        basePos.dy + (safeNum(p0, 1) * overallScale),
                      ),
                      Offset(
                        basePos.dx + (safeNum(p1, 0) * overallScale),
                        basePos.dy + (safeNum(p1, 1) * overallScale),
                      ),
                      Offset(
                        basePos.dx + (safeNum(p2, 0) * overallScale),
                        basePos.dy + (safeNum(p2, 1) * overallScale),
                      ),
                      Offset(
                        basePos.dx + (safeNum(p3, 0) * overallScale),
                        basePos.dy + (safeNum(p3, 1) * overallScale),
                      ),
                      partColor,
                      2.0 * viewScale,
                    );
                    newStrokes.add(
                      stroke.copyWith(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        semanticMeaning: compositeName,
                      ),
                    );
                  } else if (partType == 'organic_path') {
                    final bPts =
                        part['base_points'] as List? ??
                        [
                          [0, 0],
                        ];
                    final nl = (part['noise_level'] as num?)?.toDouble() ?? 3.0;
                    double safeNum(dynamic l, int idx) =>
                        (l is List && l.length > idx && l[idx] != null)
                        ? (l[idx] as num).toDouble()
                        : 0.0;
                    List<Offset> mapped = bPts
                        .map(
                          (pt) => Offset(
                            basePos.dx + (safeNum(pt, 0) * overallScale),
                            basePos.dy + (safeNum(pt, 1) * overallScale),
                          ),
                        )
                        .toList();
                    final stroke = AiStrokeGenerator.generateOrganicPath(
                      mapped,
                      nl * overallScale,
                      partColor,
                      2.0 * viewScale,
                    );
                    newStrokes.add(
                      stroke.copyWith(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        isFilled: isFilled,
                        semanticMeaning: compositeName,
                      ),
                    );
                  } else if (partType == 'polygon') {
                    final pts =
                        part['points'] as List? ??
                        [
                          [0, 0],
                        ];
                    double safeNum(dynamic l, int idx) =>
                        (l is List && l.length > idx && l[idx] != null)
                        ? (l[idx] as num).toDouble()
                        : 0.0;
                    List<Offset> mapped = pts
                        .map(
                          (pt) => Offset(
                            basePos.dx + (safeNum(pt, 0) * overallScale),
                            basePos.dy + (safeNum(pt, 1) * overallScale),
                          ),
                        )
                        .toList();
                    final stroke = AiStrokeGenerator.generatePolygon(
                      mapped,
                      partColor,
                      2.0 * viewScale,
                    );
                    newStrokes.add(
                      stroke.copyWith(
                        groupId: groupId,
                        name: part['name']?.toString(),
                        isFilled: isFilled,
                        semanticMeaning: compositeName,
                      ),
                    );
                  }

                  if (part['details'] is List) {
                    parsePartsList(part['details'] as List);
                  }
                }
              }

              parsePartsList(parts);
            }
          } else if (type == 'draw_svg') {
            final pathData = action['path'] as String?;
            final pos = action['position'] as List?;
            final id =
                action['id'] as String? ??
                DateTime.now().millisecondsSinceEpoch.toString();

            if (pathData != null) {
              final p = pos != null && pos.length >= 2
                  ? mapPoint(pos[0].toDouble(), pos[1].toDouble())
                  : mapPoint(100.0, 100.0);
              final scale = inverse.getMaxScaleOnAxis();

              final svgScale = (action['scale'] as num?)?.toDouble() ?? 1.0;
              final isFilled =
                  (action['isFilled'] ?? action['filled']) as bool? ?? false;

              try {
                final parsedPath = parseSvgPathData(pathData);

                // Move and scale the path
                final matrix = Matrix4.identity()
                  ..translate(p.dx, p.dy)
                  ..scale(svgScale * scale * 2.0);

                final transformedPath = parsedPath.transform(matrix.storage);

                for (var metric in transformedPath.computeMetrics()) {
                  List<Offset> extractedPoints = [];
                  for (double i = 0; i < metric.length; i += 4.0) {
                    // Increased step for performance
                    final tangent = metric.getTangentForOffset(i);
                    if (tangent != null) extractedPoints.add(tangent.position);
                  }
                  if (extractedPoints.isNotEmpty) {
                    newStrokes.add(
                      Stroke(
                        groupId: id,
                        name: 'svg_shape',
                        points: extractedPoints,
                        color: color,
                        size: 2.0 * scale,
                        toolType: ToolType.pen,
                        isFilled: isFilled,
                      ),
                    );
                  }
                  if (_cancelRequested) {
                    throw Exception("Cancelled by user");
                  }
                  // Yield to event loop to keep UI responsive
                  await Future.delayed(Duration.zero);
                }
              } catch (e) {
                debugPrint("WARNING: Failed to parse SVG path: $e");
                rethrow; // Rethrow so the global operation error handler catches it
              }
            }
          } else if (type == 'draw_template') {
            final textName = action['name'] as String;
            final pos = action['position'] as List?;
            final id =
                action['id'] as String? ??
                DateTime.now().millisecondsSinceEpoch.toString();

            final p = pos != null && pos.length >= 2
                ? mapPoint(pos[0].toDouble(), pos[1].toDouble())
                : mapPoint(100.0, 100.0);
            final scale = inverse.getMaxScaleOnAxis();

            final replaceName = action['replace'] as String?;
            if (replaceName != null) {
              final strokesToRemove = ref.read(drawingProvider).strokes.where((
                s,
              ) {
                return s.name == replaceName || s.groupId == replaceName;
              }).toList();
              if (strokesToRemove.isNotEmpty) {
                ref
                    .read(drawingProvider.notifier)
                    .eraseStrokes(strokesToRemove);
              }
            }

            // Collision avoidance via radial search (bypassed if overlap is requested)
            final overlap =
                action['overlap'] == true || action['allowOverlap'] == true;

            double finalX = p.dx;
            double finalY = p.dy;
            double radius = 0;
            double angle = 0;
            bool hasCollision = !overlap;

            double shapeSize = (size * scale) * 3.0;

            int iterations = 0;
            while (hasCollision && iterations < 100) {
              Rect newBounds = Rect.fromLTWH(
                finalX - 20,
                finalY - 20,
                shapeSize + 40,
                shapeSize + 40,
              );
              hasCollision = checkCollision(newBounds);

              if (hasCollision) {
                radius += 20;
                angle += 0.5; // spiral out
                finalX = p.dx + radius * math.cos(angle);
                finalY = p.dy + radius * math.sin(angle);
              }
              iterations++;
            }

            final path = SketchTemplates.getPath(
              textName,
              finalX,
              finalY,
              size *
                  2.0, // Pass the actual size parameter instead of hardcoded 100
            );

            final isFilled =
                (action['isFilled'] ?? action['filled']) as bool? ?? true;
            for (var metric in path.computeMetrics()) {
              List<Offset> extractedPoints = [];
              for (double i = 0; i < metric.length; i += 4.0) {
                // Increased step for performance
                final tangent = metric.getTangentForOffset(i);
                if (tangent != null) extractedPoints.add(tangent.position);
              }
              newStrokes.add(
                Stroke(
                  groupId: id, // Template grouping!
                  name: textName,
                  points: extractedPoints,
                  color: color,
                  size: 2.0 * scale,
                  toolType: ToolType.pen,
                  isFilled: isFilled,
                ),
              );
              // Yield to event loop to keep UI responsive
              await Future.delayed(Duration.zero);
            }
          } else if (type == 'draw_text') {
            final text = action['text'] as String;
            if (aiMessage != null) {
              final rawText = text == "Thinking..." ? _currentMessageText : text;
              final cleanText = rawText.trim();
              final cleanMsg = aiMessage.trim();
              final similarity = StringSimilarity.compareTwoStrings(cleanText, cleanMsg);
              if (cleanText == cleanMsg ||
                  similarity > 0.85 ||
                  (cleanText.length > 30 &&
                      (cleanMsg.contains(cleanText) || cleanText.contains(cleanMsg)))) {
                // Skip duplicating the main conversational response on the canvas
                continue;
              }
            }
            List? pos = action['position'] as List?;
            if (pos == null || pos.length < 2) {
              pos = [100.0, 100.0];
            }

            double rawX = pos[0].toDouble();
            double rawY = pos[1].toDouble();

            if (internalSafeY != null && rawY < internalSafeY) {
              rawY = internalSafeY;
            }
            final linesCount = text.split('\n').length;
            internalSafeY = rawY + (linesCount * 70) + 50;

            final p = mapPoint(rawX, rawY);
            final scale = inverse.getMaxScaleOnAxis();

            double finalX = p.dx;
            double finalY = p.dy;
            double radius = 0;
            double angle = 0;
            bool hasCollision = true;

            final lines = text.split('\n');
            final maxLineLength = lines.isEmpty
                ? 0
                : lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
            final textWidth = maxLineLength * (size * scale) * 3.0 * 0.6;
            final textHeight = linesCount * (size * scale) * 3.0 * 1.5;

            int iterations = 0;
            while (hasCollision && iterations < 100) {
              // Provide a generous buffer around the text
              Rect newBounds = Rect.fromCenter(
                center: Offset(
                  finalX + textWidth / 2.0,
                  finalY + textHeight / 2.0,
                ),
                width: textWidth + 80,
                height: textHeight + 60,
              );
              hasCollision = checkCollision(newBounds);

              if (hasCollision) {
                radius += 20;
                angle += 0.5; // spiral out
                finalX = p.dx + radius * math.cos(angle);
                finalY = p.dy + radius * math.sin(angle);
              }
              iterations++;
            }

            newStrokes.add(
              AiStrokeGenerator.generateText(
                text,
                finalX,
                finalY,
                color,
                18.0, // Fixed 18px font size in canvas space — consistent at all zoom levels
              ),
            );
          } else if (type == 'draw_wire') {
            final start = action['start'] as List?;
            final end = action['end'] as List?;
            if (start != null &&
                end != null &&
                start.length >= 2 &&
                end.length >= 2) {
              final p1 = mapPoint(start[0].toDouble(), start[1].toDouble());
              final p2 = mapPoint(end[0].toDouble(), end[1].toDouble());
              newStrokes.add(
                Stroke(
                  points: [p1, p2],
                  color: color,
                  size: size * scale,
                  toolType: ToolType.wire,
                ),
              );
            }
          } else if (type == 'draw_portal') {
            final pos = action['position'] as List?;
            final r = (action['radius'] as num?)?.toDouble() ?? 40.0;
            if (pos != null && pos.length >= 2) {
              final p = mapPoint(pos[0].toDouble(), pos[1].toDouble());
              newStrokes.add(
                Stroke(
                  points: [p, Offset(p.dx + r * 2, p.dy + r * 2)],
                  color: color,
                  size: size * scale,
                  toolType: ToolType.portal,
                ),
              );
            }
          } else if (type == 'insert_chemistry') {
            final formula = action['formula'] as String?;
            List? pos = action['position'] as List?;
            if (formula != null) {
              final rawP = pos != null && pos.length >= 2
                  ? mapPoint(pos[0].toDouble(), pos[1].toDouble())
                  : mapPoint(100.0, 100.0);
              final scale = inverse.getMaxScaleOnAxis();

              Offset p = rawP;
              // Prevent stacking if AI generated multiple items at the exact same coordinate
              if (lastRequestedPos != null &&
                  (rawP.dx - lastRequestedPos.dx).abs() < 5 &&
                  (rawP.dy - lastRequestedPos.dy).abs() < 5) {
                p = Offset(lastPlacedPos!.dx + 380.0 * scale, lastPlacedPos.dy);
                if (p.dx >
                    (targetTopLeft?.dx ?? mapPoint(100.0, 100.0).dx) +
                        1500.0 * scale) {
                  // wrap to next row
                  p = Offset(rawP.dx, lastPlacedPos.dy + 380.0 * scale);
                }
              }
              lastRequestedPos = rawP;
              lastPlacedPos = p;

              // NEW: fetch molecule via ChemistryService (plain JSON/SDF text ├óÔé¼ÔÇØ
              // no CORS issues, no raster PNG, no BlendMode hacks).
              final mol = await ChemistryService.fetchMolecule(formula);
              if (mol == null) {
                throw Exception('Could not find molecule data for: $formula');
              }
              newStrokes.add(
                Stroke(
                  points: [Offset(p.dx, p.dy)],
                  color: color,
                  size: 1.0,
                  toolType: ToolType.pen,
                  smiles: formula, // persisted key for re-fetch after reload
                  chemMolecule:
                      mol, // already loaded ├óÔé¼ÔÇØ no spinner needed
                  text: 'chemistry', // kept for scene graph semantic tag
                ),
              );
            }
          } else if (type == 'generate_image') {
            final prompt = action['prompt'] as String?;
            List? pos = action['position'] as List?;
            if (prompt != null) {
              final rawP = pos != null && pos.length >= 2
                  ? mapPoint(pos[0].toDouble(), pos[1].toDouble())
                  : mapPoint(100.0, 100.0);
              final scale = inverse.getMaxScaleOnAxis();

              Offset p = rawP;
              double finalX = p.dx;
              double finalY = p.dy;
              double radius = 0;
              double angle = 0;
              bool hasCollision = true;
              // onDrawStart // added onDrawStart
              int iterations = 0;
              while (hasCollision && iterations < 100) {
                Rect newBounds = Rect.fromLTWH(
                  finalX - 20,
                  finalY - 20,
                  512.0 * scale + 40.0,
                  512.0 * scale + 40.0,
                );
                hasCollision = checkCollision(newBounds);

                if (hasCollision) {
                  radius += 20;
                  angle += 0.5; // spiral out
                  finalX = p.dx + radius * math.cos(angle);
                  finalY = p.dy + radius * math.sin(angle);
                }
                iterations++;
              }
              p = Offset(finalX, finalY);

              final seed = DateTime.now().millisecondsSinceEpoch;
              final url =
                  'https://vinciboard-alpha.vercel.app/api/image?prompt=${Uri.encodeComponent(prompt)}&seed=$seed&width=512&height=512';

              final response = await http
                  .get(Uri.parse(url))
                  .timeout(
                    const Duration(seconds: 30),
                    onTimeout: () => throw Exception(
                      'Image generation timed out after 30 seconds',
                    ),
                  );
              if (response.statusCode != 200) {
                throw Exception(
                  'Image generation failed: ${response.statusCode}',
                );
              }
              final imageBytes = response.bodyBytes;
              final decodedImage = await decodeImageFromList(imageBytes);
              newStrokes.add(
                Stroke(
                  points: [Offset(p.dx, p.dy)],
                  color: color,
                  size: 1.0,
                  toolType: ToolType.pen,
                  imageBytes: imageBytes,
                  decodedImage: decodedImage,
                ),
              );
            }

          } else if (type == 'draw_wire') {
            final start = action['start'] as List?;
            final end = action['end'] as List?;
            if (start != null &&
                end != null &&
                start.length >= 2 &&
                end.length >= 2) {
              final p1 = mapPoint(start[0].toDouble(), start[1].toDouble());
              final p2 = mapPoint(end[0].toDouble(), end[1].toDouble());
              newStrokes.add(
                Stroke(
                  points: [p1, p2],
                  color: color,
                  size: size * scale,
                  toolType: ToolType.wire,
                ),
              );
            }
          } else if (type == 'draw_portal') {
            final pos = action['position'] as List?;
            final r = (action['radius'] as num?)?.toDouble() ?? 40.0;
            if (pos != null && pos.length >= 2) {
              final p = mapPoint(pos[0].toDouble(), pos[1].toDouble());
              newStrokes.add(
                Stroke(
                  points: [p, Offset(p.dx + r * 2, p.dy + r * 2)],
                  color: color,
                  size: size * scale,
                  toolType: ToolType.portal,
                ),
              );
            }
          } else if (type == 'insert_chemistry') {
            final formula = action['formula'] as String?;
            List? pos = action['position'] as List?;
            if (formula != null) {
              final rawP = pos != null && pos.length >= 2
                  ? mapPoint(pos[0].toDouble(), pos[1].toDouble())
                  : mapPoint(100.0, 100.0);
              final scale = inverse.getMaxScaleOnAxis();

              Offset p = rawP;
              // Prevent stacking if AI generated multiple items at the exact same coordinate
              if (lastRequestedPos != null &&
                  (rawP.dx - lastRequestedPos.dx).abs() < 5 &&
                  (rawP.dy - lastRequestedPos.dy).abs() < 5) {
                p = Offset(lastPlacedPos!.dx + 380.0 * scale, lastPlacedPos.dy);
                if (p.dx >
                    (targetTopLeft?.dx ?? mapPoint(100.0, 100.0).dx) +
                        1500.0 * scale) {
                  // wrap to next row
                  p = Offset(rawP.dx, lastPlacedPos.dy + 380.0 * scale);
                }
              }
              lastRequestedPos = rawP;
              lastPlacedPos = p;

              // NEW: fetch molecule via ChemistryService (plain JSON/SDF text ├óÔé¼ÔÇØ
              // no CORS issues, no raster PNG, no BlendMode hacks).
              final mol = await ChemistryService.fetchMolecule(formula);
              if (mol == null) {
                throw Exception('Could not find molecule data for: $formula');
              }
              newStrokes.add(
                Stroke(
                  points: [Offset(p.dx, p.dy)],
                  color: color,
                  size: 1.0,
                  toolType: ToolType.pen,
                  smiles: formula, // persisted key for re-fetch after reload
                  chemMolecule:
                      mol, // already loaded ├óÔé¼ÔÇØ no spinner needed
                  text: 'chemistry', // kept for scene graph semantic tag
                ),
              );
            }
          } else if (type == 'generate_image') {
            final prompt = action['prompt'] as String?;
            List? pos = action['position'] as List?;
            if (prompt != null) {
              final rawP = pos != null && pos.length >= 2
                  ? mapPoint(pos[0].toDouble(), pos[1].toDouble())
                  : mapPoint(100.0, 100.0);
              final scale = inverse.getMaxScaleOnAxis();

              Offset p = rawP;
              double finalX = p.dx;
              double finalY = p.dy;
              double radius = 0;
              double angle = 0;
              bool hasCollision = true;
              // onDrawStart // added onDrawStart
              int iterations = 0;
              while (hasCollision && iterations < 100) {
                Rect newBounds = Rect.fromLTWH(
                  finalX - 20,
                  finalY - 20,
                  512.0 * scale + 40.0,
                  512.0 * scale + 40.0,
                );
                hasCollision = checkCollision(newBounds);

                if (hasCollision) {
                  radius += 20;
                  angle += 0.5; // spiral out
                  finalX = p.dx + radius * math.cos(angle);
                  finalY = p.dy + radius * math.sin(angle);
                }
                iterations++;
              }
              p = Offset(finalX, finalY);

              final seed = DateTime.now().millisecondsSinceEpoch;
              final url =
                  'https://vinciboard-alpha.vercel.app/api/image?prompt=${Uri.encodeComponent(prompt)}&seed=$seed&width=512&height=512';

              final response = await http
                  .get(Uri.parse(url))
                  .timeout(
                    const Duration(seconds: 30),
                    onTimeout: () => throw Exception(
                      'Image generation timed out after 30 seconds',
                    ),
                  );
              if (response.statusCode != 200) {
                throw Exception(
                  'Image generation failed: ${response.statusCode}',
                );
              }
              final imageBytes = response.bodyBytes;
              final decodedImage = await decodeImageFromList(imageBytes);
              newStrokes.add(
                Stroke(
                  points: [Offset(p.dx, p.dy)],
                  color: color,
                  size: 1.0,
                  toolType: ToolType.pen,
                  imageBytes: imageBytes,
                  decodedImage: decodedImage,
                ),
              );
            }
          } else {
            debugPrint("WARNING: Unrecognized AI action type: $type");
            unrecognized.add(type.toString());
          }
        } catch (e, st) {
          debugPrint("CRITICAL ERROR executing action '$type': $e\n$st");
          final p = mapPoint(100.0, (internalSafeY ?? 100.0) + 100.0);
          newStrokes.add(
            Stroke(
              points: [p],
              color: Colors.red,
              size: 1.0,
              toolType: ToolType.pen,
              text: "├░┼©┼í┬¿ FAILED: $type\nError: $e",
            ),
          );
          // Advance safeY so next fallback stroke doesn't overlap this one
          internalSafeY = (internalSafeY ?? 100.0) + 150.0;
        }
      }
    }

    

    // Unified collision detection and auto-layout for all new AI strokes
    final currentStrokes = ref.read(drawingProvider).strokes;
    if (newStrokes.isNotEmpty && currentStrokes.isNotEmpty) {
      double eMinX = double.infinity, eMinY = double.infinity;
      double eMaxX = double.negativeInfinity, eMaxY = double.negativeInfinity;
      for (var stroke in currentStrokes) {
        for (var p in stroke.points) {
          double pMaxY = p.dy;
          if (stroke.decodedImage != null) {
            pMaxY += stroke.decodedImage!.height;
          } else if (stroke.text != null)
            pMaxY += (stroke.text!.split('\n').length) * stroke.size * 2.5;
          if (p.dx < eMinX) eMinX = p.dx;
          if (p.dy < eMinY) eMinY = p.dy;
          if (p.dx > eMaxX) eMaxX = p.dx;
          if (pMaxY > eMaxY) eMaxY = pMaxY;
        }
      }

      double nMinX = double.infinity, nMinY = double.infinity;
      double nMaxX = double.negativeInfinity, nMaxY = double.negativeInfinity;
      for (var stroke in newStrokes) {
        for (var p in stroke.points) {
          double pMaxY = p.dy;
          if (stroke.decodedImage != null) {
            pMaxY += stroke.decodedImage!.height;
          } else if (stroke.text != null)
            pMaxY += (stroke.text!.split('\n').length) * stroke.size * 2.5;
          if (p.dx < nMinX) nMinX = p.dx;
          if (p.dy < nMinY) nMinY = p.dy;
          if (p.dx > nMaxX) nMaxX = p.dx;
          if (pMaxY > nMaxY) nMaxY = pMaxY;
        }
      }
    }

    if (newStrokes.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (var s in newStrokes) {
        final b = s.bounds;
        if (b.left < minX) minX = b.left;
        if (b.top < minY) minY = b.top;
        if (b.right > maxX) maxX = b.right;
        if (b.bottom > maxY) maxY = b.bottom;
      }
      if (maxX != double.negativeInfinity) {
        final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
        drawingNotifier.setLastAddedBounds(bounds);

        CognitiveRuntime().avatarEngine.moveTo(bounds.center);
        CognitiveRuntime().avatarEngine.setState(AvatarState.generating);

        // --- COGNITIVE SPATIAL OS: Graph Registration ---
        final spatialRegistry = ref.read(spatialRegistryProvider.notifier);
        final parentId = ref.read(drawingProvider).selectedStrokes.isNotEmpty
            ? ref.read(drawingProvider).selectedStrokes.first.groupId
            : null;

        final node = SpatialNode(
          groupId:
              newStrokes.first.groupId ??
              'generated_${DateTime.now().millisecondsSinceEpoch}',
          clusterId:
              parentId ?? 'root_${DateTime.now().millisecondsSinceEpoch}',
          parentId: parentId,
          bounds: bounds,
          depth: parentId != null
              ? (spatialRegistry.getNode(parentId)?.depth ?? 0) + 1
              : 0,
          orderIndex: 0,
          semanticType: parentId == null
              ? SemanticType.root
              : SemanticType.expansion,
        );
        spatialRegistry.registerNode(node);

        // --- COGNITIVE SPATIAL OS: Camera Perception ---
        final isRoot = parentId == null;
        final intent = SemanticCameraIntelligence.determineIntent(
          userState: UserIntentState.follow, // User waiting for AI
          nodeDepth: node.depth,
          isRoot: isRoot,
          isFullyOffscreen:
              true, // We assume true for new AI generations to trigger softGuide
        );
        _eventBus.publish(
          BaseEvent.generic('aiTaskCompleted', payload: {'intent': intent}),
        );
      }
    } else if (objectsAdded > 0 || objectsUpdated > 0) {
      // Also focus if we inserted widgets or images directly
      _eventBus.publish(
        BaseEvent.generic(
          'aiTaskCompleted',
          payload: {
            'intent': CameraIntent.userAssistedFocus,
            'targetStrokeId': aiFocusTargetId,
          },
        ),
      );
    }

    if (newStrokes.isNotEmpty || objectsAdded > 0) {
      drawingNotifier.setAiStatus(null);
    }

    if (newStrokes.isNotEmpty) {
      objectsAdded += newStrokes.length;
      await drawingNotifier.animateStrokes(newStrokes);
    }

    // onDrawEnd is now handled in the finally block of _sendMessage

    final summaryParts = <String>[];
    if (objectsAdded > 0) {
      summaryParts.add("$objectsAdded টি নতুন অবজেক্ট যুক্ত হয়েছে");
    }
    if (objectsUpdated > 0) {
      summaryParts.add("$objectsUpdated টি অবজেক্ট আপডেট হয়েছে");
    }
    if (objectsRemoved > 0) {
      summaryParts.add("$objectsRemoved টি অবজেক্ট মুছে ফেলা হয়েছে");
    }
    if (unrecognized.isNotEmpty) {
      summaryParts.add(
        "Warning: Unknown actions skipped (${unrecognized.join(', ')})",
      );
    }

    return;
  }
}

final aiExecutionProvider = Provider<AiExecutionController>((ref) {
  return AiExecutionController(ref);
});
