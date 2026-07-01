import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_drawing/path_drawing.dart';
import '../engine/canvas_exporter.dart';
import '../models/stroke.dart';
import '../models/tool_type.dart';
import '../providers/drawing_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ai_chat_provider.dart';
import '../services/ai_agent_service.dart';
import '../services/memory_service.dart';
import '../services/plantuml_service.dart';
import '../utils/ai_stroke_generator.dart';
import '../utils/sketch_templates.dart';
import '../models/stroke.dart';
import '../models/tool_type.dart';

class AiChatPanel extends ConsumerStatefulWidget {
  final VoidCallback? onDrawStart;
  final void Function(double? maxY)? onDrawEnd;
  final VoidCallback? onClose;
  final Matrix4? Function()? getTransform;
  final String insertionPosition;
  final Function(Offset)? onCameraFocusRequired;

  const AiChatPanel({
    super.key,
    this.onDrawStart,
    this.onDrawEnd,
    this.onClose,
    this.getTransform,
    this.insertionPosition = 'Bottom',
    this.onCameraFocusRequired,
  });

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final TextEditingController _textController = TextEditingController();
  bool _isTyping = false;

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatNotifier = ref.read(aiChatProvider.notifier);
    final drawingNotifier = ref.read(drawingProvider.notifier);

    _textController.clear();
    chatNotifier.addMessage({'sender': 'user', 'text': text});

    setState(() => _isTyping = true);
    drawingNotifier.setAiStatus('Thinking');

    try {
      final settings = ref.read(settingsProvider);
      final provider = settings.selectedProvider;
      final modelId = settings.selectedModel;
      final apiKey = settings.apiKeys[provider] ?? '';

      final strokes = ref.read(drawingProvider).strokes;
      final screenSize = MediaQuery.of(context).size;
      final currentTransform = widget.getTransform?.call();

      final transform = currentTransform ?? Matrix4.identity();
      final scale = transform.getMaxScaleOnAxis();
      final pixelRatio = 1.0;

      final imageBytes = await CanvasExporter.exportStrokesToImage(
        strokes,
        canvasSize: screenSize,
        transform: transform,
        pixelRatio: pixelRatio,
      );

      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (var stroke in strokes) {
        for (var p in stroke.points) {
          final screenP = MatrixUtils.transformPoint(transform, p);
          double pMaxX = screenP.dx;
          double pMaxY = screenP.dy;

          if (stroke.decodedImage != null) {
            pMaxX += stroke.decodedImage!.width * scale;
            pMaxY += stroke.decodedImage!.height * scale;
          } else if (stroke.toolType == ToolType.latex && stroke.text != null) {
            final lines = stroke.text!.split('\n');
            final maxLineLength = lines
                .map((l) => l.length)
                .reduce((a, b) => a > b ? a : b);
            pMaxX += maxLineLength * stroke.size * 0.8 * scale;
            pMaxY += lines.length * stroke.size * 2.5 * scale;
          } else if (stroke.text != null) {
            final lines = stroke.text!.split('\n');
            final maxLineLength = lines
                .map((l) => l.length)
                .reduce((a, b) => a > b ? a : b);
            pMaxX += maxLineLength * stroke.size * 0.6 * scale;
            pMaxY += lines.length * stroke.size * 1.5 * scale;
          }

          if (screenP.dx < minX) minX = screenP.dx;
          if (screenP.dy < minY) minY = screenP.dy;
          if (pMaxX > maxX) maxX = pMaxX;
          if (pMaxY > maxY) maxY = pMaxY;
        }
      }

      String inkBoundsStr = "";
      Offset? canvasTargetCenter;
      
      if (minX != double.infinity) {
        final scaledMinX = (minX * pixelRatio).toInt();
        final scaledMinY = (minY * pixelRatio).toInt();
        final scaledMaxX = (maxX * pixelRatio).toInt();
        final scaledMaxY = (maxY * pixelRatio).toInt();

        // Calculate target insertion coordinates
        double targetX = (minX + maxX) / 2.0;
        double targetY = maxY + 50.0;

        switch (widget.insertionPosition) {
          case 'Bottom': targetX = (minX + maxX) / 2.0; targetY = maxY + 50.0; break;
          case 'Top': targetX = (minX + maxX) / 2.0; targetY = minY - 300.0; break;
          case 'Left': targetX = minX - 400.0; targetY = (minY + maxY) / 2.0; break;
          case 'Right': targetX = maxX + 50.0; targetY = (minY + maxY) / 2.0; break;
          case 'Diagonal': targetX = maxX + 50.0; targetY = maxY + 50.0; break;
          case 'Center': targetX = screenSize.width / 2.0; targetY = screenSize.height / 2.0; break;
        }
        
        final inverse = Matrix4.copy(transform)..invert();
        canvasTargetCenter = MatrixUtils.transformPoint(inverse, Offset(targetX, targetY));
        
        if (widget.onCameraFocusRequired != null) {
          widget.onCameraFocusRequired!(canvasTargetCenter);
        }
        
        drawingNotifier.setAiStatus('Thinking', target: canvasTargetCenter);

        final targetXScaled = (targetX * pixelRatio).toInt();
        final targetYScaled = (targetY * pixelRatio).toInt();

        final responseFormat = ref.read(settingsProvider).responseFormat;

        if (responseFormat == 'Formatted') {
          inkBoundsStr =
              "\n\n[System Note: The existing canvas content is within [minX: $scaledMinX, minY: $scaledMinY, maxX: $scaledMaxX, maxY: $scaledMaxY]. The user requested a 'Formatted' layout. YOU MUST arrange your drawings beautifully in a highly structured, organized grid or symmetric format! DO NOT OVERLAP with existing bounds.]";
        } else if (responseFormat == 'Random') {
          inkBoundsStr =
              "\n\n[System Note: The existing canvas content is within [minX: $scaledMinX, minY: $scaledMinY, maxX: $scaledMaxX, maxY: $scaledMaxY]. The user requested a 'Random' layout. YOU MUST scatter your drawings wildly and randomly across the canvas! Use completely random, scattered coordinates for each object.]";
        } else {
          inkBoundsStr =
              "\n\n[System Note: The existing canvas content is located within the bounding box [minX: $scaledMinX, minY: $scaledMinY, maxX: $scaledMaxX, maxY: $scaledMaxY]. The user requested the layout position to be '${widget.insertionPosition}'. YOU MUST output absolute coordinates that place your new drawing exactly at [x: $targetXScaled, y: $targetYScaled] to align with their request!]";
        }
      } else {
        canvasTargetCenter = MatrixUtils.transformPoint(
            Matrix4.copy(transform)..invert(),
            Offset(screenSize.width / 2.0, screenSize.height / 2.0));
            
        if (widget.onCameraFocusRequired != null) {
          widget.onCameraFocusRequired!(canvasTargetCenter);
        }
        drawingNotifier.setAiStatus('Thinking', target: canvasTargetCenter);
      }

      final scaledWidth = (screenSize.width * pixelRatio).toInt();
      final scaledHeight = (screenSize.height * pixelRatio).toInt();

      final augmentedPrompt = '''$text
[System Note: The canvas image size you are analyzing is ${scaledWidth}x$scaledHeight. You must output your coordinates based on this exact ${scaledWidth}x$scaledHeight scale.]$inkBoundsStr''';

      final currentStrokes = ref.read(drawingProvider).strokes;
      final canvasObjects = currentStrokes.map((s) {
        final screenRect = MatrixUtils.transformRect(transform, s.bounds);
        return {
          'id': s.id,
          'groupId': s.groupId,
          'name': s.name,
          'toolType': s.toolType.toString(),
          'bounds': [
            (screenRect.left * pixelRatio).toInt(),
            (screenRect.top * pixelRatio).toInt(),
            (screenRect.width * pixelRatio).toInt(),
            (screenRect.height * pixelRatio).toInt(),
          ],
        };
      }).toList();

      final chatHistory = ref.read(aiChatProvider).messages;
      final response = await AiAgentService.askAgent(
        imageBytes: imageBytes ?? [],
        prompt: augmentedPrompt,
        provider: provider,
        apiKey: apiKey,
        modelId: modelId,
        chatHistory: chatHistory,
        canvasObjects: canvasObjects,
      );

      String? diffSummary;
      String? rationaleText;
      String displayText = "";

      if (response.startsWith("AI Error") || response.startsWith("Error:")) {
        displayText = response;
      } else {
        try {
          // First try to extract from markdown blocks
          String jsonStr = response;
          final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
          final match = regex.firstMatch(response);
          if (match != null) {
            jsonStr = match.group(1)!;
          } else {
            // If no markdown blocks, try to find the first { or [ to the last } or ]
            final firstBrace = response.indexOf('{');
            final lastBrace = response.lastIndexOf('}');
            final firstBracket = response.indexOf('[');
            final lastBracket = response.lastIndexOf(']');

            int start = -1;
            int end = -1;

            if (firstBrace != -1 &&
                lastBrace != -1 &&
                (firstBracket == -1 || firstBrace < firstBracket)) {
              start = firstBrace;
              end = lastBrace + 1;
            } else if (firstBracket != -1 && lastBracket != -1) {
              start = firstBracket;
              end = lastBracket + 1;
            }

            if (start != -1 && end != -1) {
              jsonStr = response.substring(start, end);
            }
          }

          final data = jsonDecode(jsonStr);

          List actions = [];
          if (data is Map && data.containsKey('ops')) {
            actions = List.from(data['ops'] ?? []);
            rationaleText = data['rationale'] as String?;
          } else if (data is List) {
            actions = List.from(data);
          } else if (data is Map && data.containsKey('actions')) {
            actions = List.from(data['actions'] ?? []);
          }

          if (actions.isEmpty &&
              rationaleText != null &&
              rationaleText.trim().isNotEmpty) {
            final screenSize = MediaQuery.of(context).size;
            actions.add({
              "action": "draw_text",
              "text": rationaleText,
              "position": [
                screenSize.width / 2.0 - 150.0,
                screenSize.height / 2.0,
              ],
              "color": "0xFF000000",
              "size": 18.0,
            });
          }

          // Check for 'type' alias instead of 'action' in case of LLM hallucination
          for (int i = 0; i < actions.length; i++) {
             if (actions[i] is Map) {
                if (actions[i]['action'] == null && actions[i]['type'] != null) {
                   actions[i]['action'] = actions[i]['type'];
                }
             }
          }

          drawingNotifier.setAiStatus('Working', target: canvasTargetCenter);
          diffSummary = await _executeAiActions(actions);
          
          if (diffSummary == null || diffSummary.isEmpty) {
             // Fallback: forcefully draw if _executeAiActions aborted (e.g. unmounted)
             final screenSize = MediaQuery.of(context).size;
             final textToDraw = rationaleText ?? response;
             final p = widget.getTransform != null 
                 ? MatrixUtils.transformPoint(Matrix4.copy(widget.getTransform!()!)..invert(), Offset(screenSize.width / 2.0 / 2.0, screenSize.height / 2.0 / 2.0))
                 : Offset(screenSize.width / 2.0, screenSize.height / 2.0);
             drawingNotifier.addStrokes([
               AiStrokeGenerator.generateText(textToDraw, p.dx, p.dy, const Color(0xFF000000), 18.0 * 3.0)
             ]);
             diffSummary = "1 টি নতুন অবজেক্ট যুক্ত হয়েছে";
          }

          if (diffSummary.isNotEmpty) {
            // displayText = "$diffSummary\n\n";
          }
          if (rationaleText != null && rationaleText.isNotEmpty) {
            // displayText += "(AI: $rationaleText)";
          }
        } catch (e) {
          print("Failed to decode AI JSON: $e");
          // If it completely fails to parse as JSON, assume it's conversational
          
          final screenSize = MediaQuery.of(context).size;
          List actions = [{
            "action": "draw_text",
            "text": response,
            "position": [
              screenSize.width / 2.0 - 150.0,
              screenSize.height / 2.0,
            ],
            "color": "0xFF000000",
            "size": 18.0,
          }];
          
          drawingNotifier.setAiStatus('Working');
          final inverse = Matrix4.copy(transform)..invert();
          
          Offset? canvasTargetCenter;
          if (minX != double.infinity) {
            // targetX and targetY are available in the scope from earlier calculations
            double tgtX = (minX + maxX) / 2.0;
            double tgtY = maxY + 50.0;
            switch (widget.insertionPosition) {
              case 'Bottom': tgtX = (minX + maxX) / 2.0; tgtY = maxY + 50.0; break;
              case 'Top': tgtX = (minX + maxX) / 2.0; tgtY = minY - 300.0; break;
              case 'Left': tgtX = minX - 400.0; tgtY = (minY + maxY) / 2.0; break;
              case 'Right': tgtX = maxX + 50.0; tgtY = (minY + maxY) / 2.0; break;
              case 'Diagonal': tgtX = maxX + 50.0; tgtY = maxY + 50.0; break;
              case 'Center': tgtX = screenSize.width / 2.0; tgtY = screenSize.height / 2.0; break;
            }
            canvasTargetCenter = MatrixUtils.transformPoint(inverse, Offset(tgtX, tgtY));
          } else {
             canvasTargetCenter = MatrixUtils.transformPoint(inverse, Offset(screenSize.width / 2.0, screenSize.height / 2.0));
          }

          drawingNotifier.setAiStatus('Working', target: canvasTargetCenter);
          final summary = await _executeAiActions(actions, targetCenter: canvasTargetCenter);
          
          if (summary == null || summary.isEmpty) {
             // Forceful fallback if _executeAiActions aborted
             final p = widget.getTransform != null 
                 ? MatrixUtils.transformPoint(Matrix4.copy(widget.getTransform!()!)..invert(), Offset(screenSize.width / 2.0 / 2.0, screenSize.height / 2.0 / 2.0))
                 : Offset(screenSize.width / 2.0, screenSize.height / 2.0);
             drawingNotifier.addStrokes([
               AiStrokeGenerator.generateText(response, p.dx, p.dy, const Color(0xFF000000), 18.0 * 3.0)
             ]);
          }
        }
      }

      // We only want to show actual errors in the chat UI now, no success responses.
      if (displayText.startsWith("AI Error") || displayText.startsWith("Error:")) {
        if (displayText.trim().isNotEmpty) {
          chatNotifier.addMessage({'sender': 'ai', 'text': displayText.trim()});
        }
      }
    } catch (e) {
      if (mounted) {
        chatNotifier.addMessage({'sender': 'ai', 'text': 'Error: $e'});
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
      drawingNotifier.setAiStatus(null);
    }
  }

  Future<String> _executeAiActions(
    List actions, {
    bool isAnimateFrame = false,
    Offset? targetCenter,
  }) async {
    if (!mounted) return "";
    final drawingNotifier = ref.read(drawingProvider.notifier);
    final newStrokes = <Stroke>[];
    int objectsAdded = 0;
    int objectsUpdated = 0;
    int objectsRemoved = 0;
    final unrecognized = <String>[];
    final tweens = <TweenData>[];
    int maxTweenDuration = 1000;

    final transform = widget.getTransform?.call();
    Matrix4 inverse;
    if (transform != null) {
      inverse = Matrix4.copy(transform)..invert();
    } else {
      inverse = Matrix4.identity();
    }

    Offset mapPoint(double x, double y) {
      // Divide by pixelRatio = 1.0 used in CanvasExporter
      final scaledX = x / 1.0;
      final scaledY = y / 1.0;
      final point = MatrixUtils.transformPoint(
        inverse,
        Offset(scaledX, scaledY),
      );
      return point;
    }

    double? internalSafeY;

    for (var action in actions) {
      if (action is Map) {
        final type = action['action'];

        if (type == 'clear_canvas') {
          drawingNotifier.clear();
          objectsUpdated++; // Prevent fallback
          continue;
        } else if (type == 'update') {
          final targetId = action['targetId'] as String?;
          final targetGroupId = action['targetGroupId'] as String?;
          final patch = action['patch'] as Map<String, dynamic>?;
          if (patch != null && (targetId != null || targetGroupId != null)) {
            final colorHex = patch['color'] as String?;
            Color? patchColor;
            if (colorHex != null) {
              try {
                if (colorHex.startsWith('#')) {
                  patchColor = Color(
                    int.parse(colorHex.substring(1), radix: 16) + 0xFF000000,
                  );
                } else if (colorHex.startsWith('0x') || colorHex.startsWith('0X')) {
                  patchColor = Color(int.parse(colorHex.substring(2), radix: 16));
                } else {
                  patchColor = Color(int.parse(colorHex));
                }
              } catch (_) {}
            }
            final isFilled = patch['isFilled'] as bool?;

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
          final targetId = action['targetId'] as String?;
          final targetGroupId = action['targetGroupId'] as String?;
          if (targetId != null || targetGroupId != null) {
            final ids = <String>[];
            if (targetId != null) ids.add(targetId);
            if (targetGroupId != null) ids.add(targetGroupId);
            objectsRemoved += drawingNotifier.removeStrokesByIds(ids);
          }
          continue;
        } else if (type == 'tag') {
          final ids = (action['ids'] as List?)?.cast<String>();
          final name = action['name'] as String?;
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI learned a new rule: $rule')),
            );
          }
          continue;
        } else if (type == 'delete_area') {
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
          final colorHex = action['color'] as String?;
          if (colorHex != null) {
            Color? color;
            try {
              if (colorHex.startsWith('#')) {
                color = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
              } else {
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
                  as String?;
          if (effect != null) {
            drawingNotifier.triggerEasterEgg(effect);
            objectsUpdated++; // Prevent fallback
          }
          continue;
        } else if (type == 'insert_uml') {
          final umlStr = action['plantuml'] as String?;
          final posData = action['position'] as List?;
          if (umlStr != null && posData != null && posData.length >= 2) {
            final p = mapPoint(posData[0].toDouble(), posData[1].toDouble());
            final bytes = await PlantUmlService.fetchUmlImage(umlStr);
            if (bytes != null && mounted) {
              drawingNotifier.insertImage(bytes, p);
            }
          }
          continue;
        } else if (type == 'insert_widget') {
          final widgetType = action['type'] as String?;
          final posData = action['position'] as List?;
          if (widgetType != null && posData != null && posData.length >= 2) {
            final p = mapPoint(posData[0].toDouble(), posData[1].toDouble());
            final existingWidgets = drawingNotifier.state.strokes.where((s) {
              if (s.toolType != ToolType.widget || s.text == null) return false;
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
              );
              drawingNotifier.addStrokes([stroke]);
            } else {
              // Create completely new widget
              final stroke = Stroke(
                points: [p],
                color: Colors.transparent,
                size: 1.0,
                toolType: ToolType.widget,
                text: jsonEncode(action),
              );
              drawingNotifier.addStrokes([stroke]);
            }
          }
          continue;
        } else if (type == 'tween_area') {
          final rectData = action['rect'] as List?;
          if (rectData == null || rectData.length < 4) continue;
          final p1 = mapPoint(rectData[0].toDouble(), rectData[1].toDouble());
          final p2 = mapPoint(
            rectData[0].toDouble() + rectData[2].toDouble(),
            rectData[1].toDouble() + rectData[3].toDouble(),
          );
          final bounds = Rect.fromPoints(p1, p2);

          final scaleAxis = inverse.getMaxScaleOnAxis();
          final dxRaw = (action['dx'] as num?)?.toDouble() ?? 0.0;
          final dyRaw = (action['dy'] as num?)?.toDouble() ?? 0.0;

          final dx = (dxRaw / 2.0) * scaleAxis;
          final dy = (dyRaw / 2.0) * scaleAxis;
          final offset =
              MatrixUtils.transformPoint(inverse, Offset(dx, dy)) -
              MatrixUtils.transformPoint(inverse, Offset.zero);

          final scale = (action['scale'] as num?)?.toDouble() ?? 1.0;
          final rotation = (action['rotation'] as num?)?.toDouble() ?? 0.0;
          final duration = (action['duration_ms'] as num?)?.toInt() ?? 1000;
          if (duration > maxTweenDuration) maxTweenDuration = duration;

          tweens.add(TweenData(bounds, offset.dx, offset.dy, scale, rotation));
          continue;
        } else if (type == 'apply_gravity') {
          final targetId = action['targetId'] as String?;
          final targetGroupId = action['targetGroupId'] as String?;
          final scaleAxis = inverse.getMaxScaleOnAxis();
          final duration = 2000;
          if (duration > maxTweenDuration) maxTweenDuration = duration;
          
          final currentStrokes = ref.read(drawingProvider).strokes;
          Iterable<Stroke> targetStrokes = currentStrokes;
          
          if (targetId != null) {
            targetStrokes = currentStrokes.where((s) => s.id == targetId);
          } else if (targetGroupId != null) {
            targetStrokes = currentStrokes.where((s) => s.groupId == targetGroupId);
          } else {
            // Apply to the most recently added group if no target is specified
            if (currentStrokes.isNotEmpty) {
              final lastGroupId = currentStrokes.last.groupId;
              if (lastGroupId != null) {
                targetStrokes = currentStrokes.where((s) => s.groupId == lastGroupId);
              } else {
                targetStrokes = [currentStrokes.last];
              }
            } else {
              targetStrokes = [];
            }
          }
          
          for (var stroke in targetStrokes) {
            final dy = (1000.0 / 1.0) * scaleAxis; // Large drop
            final offset =
                MatrixUtils.transformPoint(inverse, Offset(0, dy)) -
                MatrixUtils.transformPoint(inverse, Offset.zero);
            tweens.add(TweenData(stroke.bounds, offset.dx, offset.dy, 1.0, 0.0));
          }
          objectsUpdated++; // Prevent fallback
          continue;
        }

        final colorStr = action['color'] as String? ?? '0xFF000000';
        Color color = const Color(0xFF000000);
        try {
          if (colorStr.startsWith('#')) {
            color = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          } else if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
            color = Color(int.parse(colorStr.substring(2), radix: 16));
          } else {
            color = Color(int.parse(colorStr));
          }
        } catch (_) {}

        // Robustly parse size
        double size = 1.0;
        try {
          final rawSize = action['size'];
          if (rawSize is num) {
            size = rawSize.toDouble() / 2.0;
          } else if (rawSize is String) {
            size = (double.tryParse(rawSize) ?? 2.0) / 2.0;
          }
        } catch (_) {}
        if (type == 'draw_rect') {
          final rectData = action['rect'] as List?;
          if (rectData == null || rectData.length < 4) continue;
          final p1 = mapPoint(rectData[0].toDouble(), rectData[1].toDouble());
          final p2 = mapPoint(
            rectData[0].toDouble() + rectData[2].toDouble(),
            rectData[1].toDouble() + rectData[3].toDouble(),
          );
          newStrokes.add(
            AiStrokeGenerator.generateRect(
              p1.dx,
              p1.dy,
              p2.dx - p1.dx,
              p2.dy - p1.dy,
              color,
              size,
            ),
          );
        } else if (type == 'draw_circle') {
          final center = action['center'] as List?;
          if (center == null || center.length < 2) continue;
          final p = mapPoint(center[0].toDouble(), center[1].toDouble());
          final scale = inverse.getMaxScaleOnAxis();
          final radius = ((action['radius'] as num).toDouble() / 2.0) * scale;
          newStrokes.add(
            AiStrokeGenerator.generateCircle(p.dx, p.dy, radius, color, size),
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
            AiStrokeGenerator.generatePolygon(mappedPoints, color, size),
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
        } else if (type == 'draw_svg') {
          final pathData = action['path'] as String?;
          final pos = action['position'] as List?;
          final id =
              action['id'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString();

          if (pathData != null && pos != null && pos.length >= 2) {
            double rawX = pos[0].toDouble();
            double rawY = pos[1].toDouble();
            final p = mapPoint(rawX, rawY);
            final scale = inverse.getMaxScaleOnAxis();

            final svgScale = (action['scale'] as num?)?.toDouble() ?? 1.0;
            final isFilled = action['isFilled'] as bool? ?? false;

            try {
              final parsedPath = parseSvgPathData(pathData);

              // Move and scale the path
              final matrix = Matrix4.identity()
                ..translate(p.dx, p.dy)
                ..scale(svgScale * scale * 2.0);

              final transformedPath = parsedPath.transform(matrix.storage);

              for (var metric in transformedPath.computeMetrics()) {
                List<Offset> extractedPoints = [];
                for (double i = 0; i < metric.length; i += 4.0) { // Increased step for performance
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
                // Yield to event loop to keep UI responsive
                await Future.delayed(Duration.zero);
              }
            } catch (e) {
              print("WARNING: Failed to parse SVG path: $e");
            }
          }
        } else if (type == 'draw_template') {
          final textName = action['name'] as String;
          final pos = action['position'] as List?;
          final id =
              action['id'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString();
          if (pos == null || pos.length < 2) continue;

          double rawX = pos[0].toDouble();
          double rawY = pos[1].toDouble();

          final p = mapPoint(rawX, rawY);
          final scale = inverse.getMaxScaleOnAxis();
          final mode = ref.read(settingsProvider).artStyleMode;

          final replaceName = action['replace'] as String?;
          if (replaceName != null) {
            final strokesToRemove = ref.read(drawingProvider).strokes.where((
              s,
            ) {
              return s.name == replaceName || s.groupId == replaceName;
            }).toList();
            if (strokesToRemove.isNotEmpty) {
              ref.read(drawingProvider.notifier).eraseStrokes(strokesToRemove);
            }
          }

          // Collision avoidance via radial search
          final currentStrokes = ref.read(drawingProvider).strokes;
          final List<Rect> existingBounds = [];
          for (var s in currentStrokes) {
            if (s.points.isNotEmpty) {
              existingBounds.add(s.bounds);
            }
          }
          for (var s in newStrokes) {
            if (s.points.isNotEmpty) {
              existingBounds.add(s.bounds);
            }
          }

          double finalX = p.dx;
          double finalY = p.dy;
          double radius = 0;
          double angle = 0;
          bool hasCollision = true;

          double shapeSize = (size * scale) * 3.0;

          int iterations = 0;
          while (hasCollision && iterations < 100) {
            hasCollision = false;
            Rect newBounds = Rect.fromCenter(
              center: Offset(finalX, finalY),
              width: shapeSize + 40,
              height: shapeSize + 40,
            );

            for (var b in existingBounds) {
              if (newBounds.overlaps(b)) {
                hasCollision = true;
                break;
              }
            }

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
            mode,
            finalX,
            finalY,
            (size * scale) * 3.0,
          );

          final isFilled = action['isFilled'] as bool? ?? false;
          for (var metric in path.computeMetrics()) {
            List<Offset> extractedPoints = [];
            for (double i = 0; i < metric.length; i += 4.0) { // Increased step for performance
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

          final currentStrokes = ref.read(drawingProvider).strokes;
          final List<Rect> existingBounds = [];
          for (var s in currentStrokes) {
            if (s.points.isNotEmpty) {
              existingBounds.add(s.bounds);
            }
          }
          for (var s in newStrokes) {
            if (s.points.isNotEmpty) {
              existingBounds.add(s.bounds);
            }
          }

          double finalX = p.dx;
          double finalY = p.dy;
          double radius = 0;
          double angle = 0;
          bool hasCollision = true;

          final maxLineLength = text.split('\n').map((l) => l.length).reduce(math.max);
          final textWidth = maxLineLength * (size * scale) * 3.0 * 0.6;
          final textHeight = linesCount * (size * scale) * 3.0 * 1.5;

          int iterations = 0;
          while (hasCollision && iterations < 100) {
            hasCollision = false;
            // Provide a generous buffer around the text
            Rect newBounds = Rect.fromCenter(
              center: Offset(finalX + textWidth / 2.0, finalY + textHeight / 2.0),
              width: textWidth + 80,
              height: textHeight + 60,
            );

            for (var b in existingBounds) {
              if (newBounds.overlaps(b)) {
                hasCollision = true;
                break;
              }
            }

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
              (size * scale) * 3.0,
            ),
          );
        } else {
          print("WARNING: Unrecognized AI action type: $type");
          if (type != null) unrecognized.add(type.toString());
        }
      }
    }

    if (!mounted) return "";

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

      // Removed strict auto-layout. We must trust the AI's spatial coordinates so it can draw things around/next to other objects!
    }

    // INTERCEPT: Automatically shift all newly generated strokes to perfectly align with targetCenter!
    if (newStrokes.isNotEmpty && targetCenter != null && widget.insertionPosition != 'Formatted' && widget.insertionPosition != 'Random') {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (var s in newStrokes) {
        for (var p in s.points) {
          if (p.dx < minX) minX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy > maxY) maxY = p.dy;
        }
      }
      
      if (minX != double.infinity) {
        final currentCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
        final shift = targetCenter - currentCenter;
        
        for (int i = 0; i < newStrokes.length; i++) {
          final s = newStrokes[i];
          final shiftedPoints = s.points.map((p) => p + shift).toList();
          newStrokes[i] = s.copyWith(points: shiftedPoints);
        }
      }
    }

    double? finalMaxY;
    if (newStrokes.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (var s in newStrokes) {
        for (var p in s.points) {
          if (p.dx < minX) minX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dx > maxX) maxX = p.dx;

          double pMaxY = p.dy;
          if (s.decodedImage != null) {
            pMaxY += s.decodedImage!.height;
          } else if (s.text != null)
            pMaxY += (s.text!.split('\n').length) * s.size * 2.5;
          if (pMaxY > maxY) maxY = pMaxY;
        }
      }
      if (maxX != double.negativeInfinity) {
        drawingNotifier.setLastAddedBounds(
          Rect.fromLTRB(minX, minY, maxX, maxY),
        );
        finalMaxY = maxY;
      }
    }

    if (tweens.isNotEmpty || newStrokes.isNotEmpty) {
      drawingNotifier.setAiStatus(null);
      widget.onDrawStart?.call();
    }

    if (tweens.isNotEmpty) {
      await drawingNotifier.tweenStrokes(tweens, durationMs: maxTweenDuration);
    }

    if (newStrokes.isNotEmpty) {
      objectsAdded += newStrokes.length;
      if (isAnimateFrame) {
        drawingNotifier.addStrokes(newStrokes);
      } else {
        await drawingNotifier.animateStrokes(newStrokes);
      }
    }

    if (mounted && (tweens.isNotEmpty || newStrokes.isNotEmpty)) {
      widget.onDrawEnd?.call(finalMaxY);
    }

    final summaryParts = <String>[];
    if (objectsAdded > 0) {
      summaryParts.add("$objectsAdded টি নতুন অবজেক্ট যুক্ত হয়েছে");
    }
    if (objectsUpdated > 0) {
      summaryParts.add("$objectsUpdated টি অবজেক্ট আপডেট হয়েছে");
    }
    if (objectsRemoved > 0) {
      summaryParts.add("$objectsRemoved টি অবজেক্ট মুছে ফেলা হয়েছে");
    }
    if (unrecognized.isNotEmpty) {
      summaryParts.add(
        "Warning: Unknown actions skipped (${unrecognized.join(', ')})",
      );
    }

    return summaryParts.isEmpty ? "" : "${summaryParts.join(", ")}।";
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final messages = ref.watch(aiChatProvider).messages;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: math.min(350, MediaQuery.of(context).size.width - 32),
          height: math.min(500, MediaQuery.of(context).size.height - 250),
          margin: EdgeInsets.only(
            bottom: keyboardHeight > 0 ? keyboardHeight + 16 : 80,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6E4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: Color(0xFF1E40AF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Vinci',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.black54),
                      onSelected: (val) {
                        if (val == 'clear') {
                          ref.read(aiChatProvider.notifier).clear();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear all'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6E4FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.palette_outlined,
                              color: Color(0xFF1E40AF),
                              size: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const _BouncingDots(),
                          ),
                        ],
                      );
                    }

                    final msg = messages[index];
                    final isUser = msg['sender'] == 'user';

                    if (isUser) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF1F5F9,
                            ), // Normal light grey message style
                            borderRadius: BorderRadius.circular(
                              16,
                            ).copyWith(bottomRight: Radius.zero),
                          ),
                          child: Text(
                            msg['text']!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6E4FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.palette_outlined,
                                color: Color(0xFF1E40AF),
                                size: 16,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA), // Light grey
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  msg['text']!,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),

              // Input Area
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Ask Vinci to do something',
                          hintStyle: TextStyle(color: Colors.black54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final val = math.sin(
              (_controller.value * 2 * math.pi) - (index * 1.5),
            );
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              transform: Matrix4.translationValues(0, -4 * val.abs(), 0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3 + 0.7 * val.abs()),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
