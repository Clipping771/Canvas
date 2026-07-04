import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:image_picker/image_picker.dart';
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
import '../services/chemistry_service.dart';
import '../utils/ai_stroke_generator.dart';
import '../utils/sketch_templates.dart';
import '../models/spatial_node.dart';
import '../engine/weight_controller.dart';
import '../engine/semantic_camera.dart';
import '../providers/spatial_registry_provider.dart';
import '../core/event_bus.dart';
import '../engine/cognitive/cognitive_runtime.dart';
import '../engine/cognitive/avatar_engine.dart';

class AiChatPanel extends ConsumerStatefulWidget {
  final VoidCallback? onDrawStart;
  final void Function(double? maxY)? onDrawEnd;
  final VoidCallback? onClose;
  final Matrix4? Function()? getTransform;
  const AiChatPanel({
    super.key,
    this.onDrawStart,
    this.onDrawEnd,
    this.onClose,
    this.getTransform,
  });

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _cancelRequested = false;
  AiTutorMode _selectedTutorMode = AiTutorMode.normal;
  Completer<String>? _cancelCompleter;
  Uint8List? _attachedImage;

  StreamSubscription? _cancelSub;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {}); // For dynamic clear button
    });
    _cancelSub = EventBus().subscribe(EventType.cancelGeneration, (_) {
      if (_isTyping) {
        setState(() {
          _cancelRequested = true;
          AiAgentService.cancelRequest();
        });
        if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
          _cancelCompleter!.complete("Cancelled by user");
        }
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _cancelSub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() async {
    if (_isTyping) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the current request to finish.')),
      );
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImage == null) return;

    final chatNotifier = ref.read(aiChatProvider.notifier);
    final drawingNotifier = ref.read(drawingProvider.notifier);

    _textController.clear();
    
    final currentAttachedImage = _attachedImage;
    setState(() {
      _attachedImage = null;
    });

    chatNotifier.addMessage({
      'sender': 'user', 
      'text': text,
      if (currentAttachedImage != null) 'image': currentAttachedImage,
    });
    _scrollToBottom();
    
    _cancelCompleter = Completer<String>();

    setState(() {
      _isTyping = true;
      _cancelRequested = false;
    });
    drawingNotifier.setAiStatus('Thinking');
    
    CognitiveRuntime().avatarEngine.setState(AvatarState.thinking);
    final screenSize = MediaQuery.of(context).size;
    final transform = widget.getTransform?.call() ?? Matrix4.identity();
    final inverse = Matrix4.copy(transform)..invert();
    final canvasCenterPos = MatrixUtils.transformPoint(inverse, Offset(screenSize.width / 2, screenSize.height / 2));
    CognitiveRuntime().avatarEngine.moveTo(canvasCenterPos);

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
      // COMPRESSION: Send low-res image to AI to reduce latency and token usage
      final pixelRatio = 0.5;

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
      Offset? targetTopLeft;
      
      if (minX != double.infinity) {

        // --- COGNITIVE SPATIAL OS: Layout Intelligence Layer ---
        final spatialRegistry = ref.read(spatialRegistryProvider.notifier);
        final drawingState = ref.read(drawingProvider);
        final parentId = drawingState.selectedStrokes.isNotEmpty ? drawingState.selectedStrokes.first.groupId : null;
        
        final contexts = <InteractionContext>{};
        if (drawingState.selectedStrokes.isNotEmpty) contexts.add(InteractionContext.branching);
        else contexts.add(InteractionContext.newThread);
        
        // Transform viewport to scene coordinates
        final inverse = Matrix4.copy(transform)..invert();
        final viewportRect = Rect.fromPoints(
          MatrixUtils.transformPoint(inverse, const Offset(0, 0)),
          MatrixUtils.transformPoint(inverse, Offset(screenSize.width, screenSize.height))
        );
        
        final parentBounds = parentId != null ? spatialRegistry.getParentBounds(parentId) : null;
            
        final optimalOffset = ref.read(spatialRegistryProvider).layoutEngine.computeOptimalPlacement(
          nodeSize: const Size(400, 400), // Estimated generation size
          parentBounds: parentBounds,
          viewportBounds: viewportRect,
          contexts: contexts,
          groupId: 'pending_ai_task',
        );

        targetTopLeft = optimalOffset; 
        canvasTargetCenter = optimalOffset + const Offset(400, 200); // Center camera on the text block
        
        final viewportTarget = MatrixUtils.transformPoint(transform, optimalOffset);
        final targetX = viewportTarget.dx;
        final targetY = viewportTarget.dy;
        
        drawingNotifier.setAiStatus('Thinking', target: canvasTargetCenter);

        final targetXScaled = (targetX * pixelRatio).toInt();
        final targetYScaled = (targetY * pixelRatio).toInt();

        inkBoundsStr =
            "\n\n[System Note: If you are answering a general question or creating a new conversational response, YOU MUST place it exactly at coordinates X=$targetXScaled, Y=$targetYScaled. This is the layout engine's designated spot for your new response. HOWEVER, if the user asks you to modify, paint, fill, circle, or interact with an existing object (like a bottle, drawing, etc), YOU MUST use that object's exact original coordinates from the canvas to place your drawing precisely over or inside it. DO NOT assume (0,0) for anything.]";
      } else {
        final targetX = screenSize.width / 2.0;
        final targetY = screenSize.height / 2.0;
        canvasTargetCenter = MatrixUtils.transformPoint(
            Matrix4.copy(transform)..invert(),
            Offset(targetX, targetY));
        
        targetTopLeft = canvasTargetCenter;
             
        drawingNotifier.setAiStatus('Thinking', target: canvasTargetCenter);
        
        final targetXScaled = (targetX * pixelRatio).toInt();
        final targetYScaled = (targetY * pixelRatio).toInt();
        
        inkBoundsStr = "\n\n[System Note: The canvas is currently empty. Place your response exactly at coordinates X=$targetXScaled, Y=$targetYScaled.]";
      }

      final scaledWidth = (screenSize.width * pixelRatio).toInt();
      final scaledHeight = (screenSize.height * pixelRatio).toInt();

      final augmentedPrompt = '''$text
[System Note: The canvas image size you are analyzing is ${scaledWidth}x$scaledHeight. You must output your coordinates based on this exact ${scaledWidth}x$scaledHeight scale.]$inkBoundsStr''';

      // --- Context Slicing System (Phase 2) ---
      final drawingState = ref.read(drawingProvider);
      final viewportRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
      
      List<Stroke> targetStrokes = drawingState.selectedStrokes.isNotEmpty 
          ? drawingState.selectedStrokes 
          : drawingState.strokes;

      // Token Compression: Only send meaningful semantic objects or grouped objects.
      // For raw loose strokes, we will compute spatial clusters so distinct drawings aren't merged!
      final canvasObjects = <Map<String, dynamic>>[];
      final rawStrokes = <Stroke>[];

      for (var s in targetStrokes) {
        final screenRect = MatrixUtils.transformRect(transform, s.bounds);
        
        // Viewport Slicing (skip if not on screen and not explicitly selected)
        if (drawingState.selectedStrokes.isEmpty && !viewportRect.overlaps(screenRect)) {
           continue; 
        }

        if (s.groupId != null || s.semanticMeaning != null || s.toolType != ToolType.pen) {
          canvasObjects.add({
            'id': s.id,
            'groupId': s.groupId,
            'type': s.semanticMeaning ?? s.toolType.toString().split('.').last,
            'bounds': [
              (screenRect.left * pixelRatio).toInt(),
              (screenRect.top * pixelRatio).toInt(),
              (screenRect.width * pixelRatio).toInt(),
              (screenRect.height * pixelRatio).toInt(),
            ],
          });
        } else {
          rawStrokes.add(s);
        }
      }

      if (rawStrokes.isNotEmpty) {
        List<List<Stroke>> clusters = [];
        for (var s in rawStrokes) {
          final sBounds = MatrixUtils.transformRect(transform, s.bounds).inflate(20.0);
          bool foundCluster = false;
          for (var cluster in clusters) {
            Rect clusterBounds = MatrixUtils.transformRect(transform, cluster.first.bounds);
            for (int i = 1; i < cluster.length; i++) {
              clusterBounds = clusterBounds.expandToInclude(MatrixUtils.transformRect(transform, cluster[i].bounds));
            }
            if (sBounds.overlaps(clusterBounds.inflate(20.0))) {
              cluster.add(s);
              foundCluster = true;
              break;
            }
          }
          if (!foundCluster) {
            clusters.add([s]);
          }
        }
        
        // Greedy merge overlapping clusters
        bool merged;
        do {
          merged = false;
          for (int i = 0; i < clusters.length; i++) {
            for (int j = i + 1; j < clusters.length; j++) {
              Rect b1 = MatrixUtils.transformRect(transform, clusters[i].first.bounds);
              for (int k = 1; k < clusters[i].length; k++) b1 = b1.expandToInclude(MatrixUtils.transformRect(transform, clusters[i][k].bounds));
              
              Rect b2 = MatrixUtils.transformRect(transform, clusters[j].first.bounds);
              for (int k = 1; k < clusters[j].length; k++) b2 = b2.expandToInclude(MatrixUtils.transformRect(transform, clusters[j][k].bounds));
              
              if (b1.inflate(20.0).overlaps(b2.inflate(20.0))) {
                clusters[i].addAll(clusters[j]);
                clusters.removeAt(j);
                merged = true;
                break;
              }
            }
            if (merged) break;
          }
        } while (merged);
        
        for (var cluster in clusters) {
          Rect b = MatrixUtils.transformRect(transform, cluster.first.bounds);
          for (int i = 1; i < cluster.length; i++) {
            b = b.expandToInclude(MatrixUtils.transformRect(transform, cluster[i].bounds));
          }
          
          canvasObjects.add({
            'type': 'raw_handwriting_or_sketch',
            'stroke_count': cluster.length,
            'ids': cluster.map((e) => e.id).toList(),
            'bounds': [
              (b.left * pixelRatio).toInt(),
              (b.top * pixelRatio).toInt(),
              (b.width * pixelRatio).toInt(),
              (b.height * pixelRatio).toInt(),
            ],
          });
        }
      }

      // --- Deterministic Gate Engine (Layer 1) ---
      double baseAmbiguityScore = 0.0;
      final textLower = text.toLowerCase().trim();
      final ambiguousKeywords = ['something', 'nice', 'cool', 'diagram', 'system', 'it', 'this', 'that', 'mindmap', 'ui', 'app', 'design'];
      
      if (textLower.length < 30) {
        final words = textLower.split(RegExp(r'\s+'));
        int ambiguousCount = 0;
        for (var word in words) {
          if (ambiguousKeywords.contains(word)) {
            ambiguousCount++;
          }
        }
        if (ambiguousCount > 0 && words.length <= 5) {
          baseAmbiguityScore = 0.8;
        } else if (ambiguousCount > 0) {
          baseAmbiguityScore = 0.5;
        }
      }

      final chatHistory = ref.read(aiChatProvider).messages;
      // currentSettings already read above as `settings` — no need to re-read
      
      final response = await Future.any([
        AiAgentService.askAgent(
          imageBytes: imageBytes ?? [],
          attachedImageBytes: currentAttachedImage,
          prompt: augmentedPrompt,
          provider: provider,
          apiKey: apiKey,
          modelId: modelId,
          chatHistory: chatHistory.map((m) {
            // Skip the 'image' key — Uint8List.toString() produces a useless
            // number-array string that wastes tokens. The canvas screenshot
            // already captures all visible content.
            return Map.fromEntries(
              m.entries
                  .where((e) => e.key != 'image')
                  .map((e) => MapEntry<String, String>(e.key, e.value.toString())),
            );
          }).toList(),
          canvasObjects: canvasObjects,
          baseAmbiguityScore: baseAmbiguityScore,
          tutorMode: _selectedTutorMode,
        ),
        _cancelCompleter!.future,
      ]);

      // Debug logging removed — was using a hardcoded developer path that would
      // crash on any other machine. Use debugPrint for safe cross-platform logging.
      debugPrint("=== AI RESPONSE ===\n$response");

      if (response == "Cancelled by user" || _cancelRequested) {
        throw Exception("Cancelled by user");
      }

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
        
        if (_cancelRequested) {
          throw Exception("Cancelled by user");
        }

        final data = jsonDecode(jsonStr);

          List actions = [];
          String? aiMessage;
          if (data is Map) {
            aiMessage = data['message'] as String?;
            if (data.containsKey('ops')) {
              actions = List.from(data['ops'] ?? []);
            } else if (data.containsKey('actions')) {
              actions = List.from(data['actions'] ?? []);
            }
            rationaleText = data['rationale'] as String?;

            // --- LLM Refinement Clamping (Layer 2) ---
            if (data.containsKey('intent_analysis')) {
              final intentAnalysis = data['intent_analysis'];
              if (intentAnalysis is Map && intentAnalysis.containsKey('ambiguity_score')) {
                 double llmScore = (intentAnalysis['ambiguity_score'] as num).toDouble();
                 // Clamp to ±0.2 of baseAmbiguityScore
                 if (llmScore > baseAmbiguityScore + 0.2) llmScore = baseAmbiguityScore + 0.2;
                 if (llmScore < baseAmbiguityScore - 0.2) llmScore = baseAmbiguityScore - 0.2;
                 
                 // If the final score is > 0.7, enforce Clarification Gate
                 if (llmScore > 0.7 || (data.containsKey('step_0_ambiguity_gate') && data['step_0_ambiguity_gate']['decision'] == 'ask_clarification')) {
                    if (actions.isNotEmpty) {
          debugPrint("Client-Side Gate: Ops rejected due to high ambiguity score.");
                       actions.clear();
                       // Observable Enforcement: Inject a system message to correct state sync
                       chatNotifier.addMessage({'sender': 'ai', 'text': '[System: Ops blocked by ambiguity gate. The AI generated actions but they were rejected for being too ambiguous without clarification.]'});
                    }
                 }
              }
            }
          } else if (data is List) {
            actions = List.from(data);
          }
          // Force all conversational AI responses to be drawn on canvas instead of chat UI
          final textToDraw = (aiMessage != null && aiMessage.trim().isNotEmpty) ? aiMessage.trim() : rationaleText?.trim();
          
          if (actions.isEmpty && textToDraw != null && textToDraw.isNotEmpty) {
            Offset? targetCanvasPos = canvasTargetCenter;
            actions.add({
              "action": "draw_text",
              "text": textToDraw,
              "position": [
                targetCanvasPos?.dx ?? 100.0,
                targetCanvasPos?.dy ?? 100.0,
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
          try {
            // --- Multi-Intent Router & Engine Priority Integration (Phase 1) ---
            // Future integration: MultiIntentRouter().routeOps(actions);
            // For now, executing through legacy block with Safe Mode wrapper.
            diffSummary = await _executeAiActions(actions, targetTopLeft: targetTopLeft);
            
            if (diffSummary.isEmpty) {
               diffSummary = "";
            }
          } catch (engineError) {
          debugPrint("Engine Error during execution: $engineError");
             // --- Safe Mode Fallback ---
             chatNotifier.addMessage({
               'sender': 'system', 
               'text': '[Safe Mode Activated] A rendering engine encountered a critical error. Falling back to safe static canvas.'
             });
             // Disable physics/animations temporarily if needed
             // drawingNotifier.disablePhysicsTemporary();
             diffSummary = "Safe Mode active";
          }

          if (diffSummary.isNotEmpty) {
            // displayText = "$diffSummary\n\n";
          }
          if (rationaleText != null && rationaleText.isNotEmpty) {
            // displayText += "(AI: $rationaleText)";
          }
        } catch (e) {
          debugPrint("Failed to decode AI JSON: $e");
          
          final isJsonAttempt = response.trim().startsWith('{') || response.trim().startsWith('```');
          String textToDraw = response.trim();
          
          if (isJsonAttempt) {
             // It's a malformed JSON. Don't draw the raw JSON code on the canvas!
             // Let's try to extract just the message field using regex
             final msgMatch = RegExp(r'"message"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"').firstMatch(response);
             if (msgMatch != null) {
                textToDraw = msgMatch.group(1)!.replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
             } else {
                textToDraw = "Oops! I had a little hiccup formatting my thoughts.";
             }
          }

          final screenSize = MediaQuery.of(context).size;
          drawingNotifier.setAiStatus('Working');
          
          final inverse = Matrix4.copy(transform)..invert();
          final catchTargetCenter = MatrixUtils.transformPoint(inverse, Offset(screenSize.width / 2.0, screenSize.height / 2.0));
          
          List actions = [{
            "action": "draw_text",
            "text": textToDraw,
            "position": [
              catchTargetCenter.dx,
              catchTargetCenter.dy,
            ],
            "color": "0xFF000000",
            "size": 18.0,
          }];

          drawingNotifier.setAiStatus('Working', target: catchTargetCenter);
          await _executeAiActions(actions, targetTopLeft: catchTargetCenter);
        }
      }

      // We removed adding displayText to chatNotifier here because 
      // the user strictly wants responses ONLY on the canvas.
      if (displayText.trim().isNotEmpty && displayText.contains('[System')) {
        // Only system warnings/enforcements are allowed in chat
        chatNotifier.addMessage({'sender': 'system', 'text': displayText.trim()});
      }
    } catch (e) {
      if (mounted) {
        debugPrint("AI Chat Panel Raw Error: $e");
        chatNotifier.addMessage({'sender': 'ai', 'text': 'Network error, please check your connection.'});
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
      drawingNotifier.setAiStatus(null);
      CognitiveRuntime().avatarEngine.setState(AvatarState.idle);
    }
  }

  Future<String> _executeAiActions(
    List actions, {
    bool isAnimateFrame = false,
    Offset? targetTopLeft,
  }) async {
    if (!mounted) return "";
    final drawingNotifier = ref.read(drawingProvider.notifier);
    final newStrokes = <Stroke>[];
    int objectsAdded = 0;
    int objectsUpdated = 0;
    int objectsRemoved = 0;
    final unrecognized = <String>[];

    final transform = widget.getTransform?.call();
    Matrix4 inverse;
    if (transform != null) {
      inverse = Matrix4.copy(transform)..invert();
    } else {
      inverse = Matrix4.identity();
    }

    Offset mapPoint(double x, double y) {
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

    for (var action in actions) {
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
          final patch = action['patch'] is Map ? action['patch'] as Map : null;
          if (patch != null && (targetId != null || targetGroupId != null)) {
            final colorHex = patch['color']?.toString();
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
                  // Fallback for named colors if they hallucinate
                  if (colorHex.toLowerCase() == 'red') patchColor = Colors.red;
                  else if (colorHex.toLowerCase() == 'blue') patchColor = Colors.blue;
                  else if (colorHex.toLowerCase() == 'green') patchColor = Colors.green;
                  else if (colorHex.toLowerCase() == 'yellow') patchColor = Colors.yellow;
                  else if (colorHex.toLowerCase() == 'black') patchColor = Colors.black;
                  else if (colorHex.toLowerCase() == 'white') patchColor = Colors.white;
                  else patchColor = Color(int.parse(colorHex));
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
          final ids = action['ids'] is List ? (action['ids'] as List).map((e) => e.toString()).toList() : null;
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI learned a new rule: $rule')),
            );
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
                color = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
              } else {
                // Fallback for named colors
                if (colorHex.toLowerCase() == 'red') color = Colors.red;
                else if (colorHex.toLowerCase() == 'blue') color = Colors.blue;
                else if (colorHex.toLowerCase() == 'green') color = Colors.green;
                else if (colorHex.toLowerCase() == 'yellow') color = Colors.yellow;
                else if (colorHex.toLowerCase() == 'black') color = Colors.black;
                else if (colorHex.toLowerCase() == 'white') color = Colors.white;
                else color = Color(int.parse(colorHex));
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
                      action['type'])?.toString();
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
            if (targetTopLeft != null) {
              rawX = targetTopLeft.dx;
              rawY = targetTopLeft.dy;
            } else if (posData != null && posData.length >= 2) {
              rawX = posData[0].toDouble();
              rawY = posData[1].toDouble();
            }
            final p = targetTopLeft != null 
                ? targetTopLeft 
                : mapPoint(rawX, rawY);

            final bytes = await PlantUmlService.fetchUmlImage(umlStr);
            if (bytes != null && mounted) {
              try {
                // Pre-decode the image so the bounding box is correct instantly
                final decodedImage = await decodeImageFromList(bytes);
                newStrokes.add(Stroke(
                  points: [p],
                  color: Colors.transparent,
                  size: 1.0,
                  toolType: ToolType.pan,
                  imageBytes: bytes,
                  decodedImage: decodedImage,
                ));
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
            EventBus().publish(EventType.aiTaskCompleted, {'intent': CameraIntent.hardFocus});
          }
          continue;
        } else if (type == 'insert_widget') {
          final widgetType = action['type']?.toString();
          final posData = action['position'] as List?;
          if (widgetType != null) {
            double rawX = 100.0, rawY = 100.0;
            if (targetTopLeft != null) {
              rawX = targetTopLeft.dx;
              rawY = targetTopLeft.dy;
            } else if (posData != null && posData.length >= 2) {
              rawX = posData[0].toDouble();
              rawY = posData[1].toDouble();
            }
            final p = targetTopLeft != null 
                ? targetTopLeft 
                : mapPoint(rawX, rawY);

            final existingWidgets = ref.read(drawingProvider).strokes.where((s) {
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
        } else if (type == 'apply_gravity') {
          final targetGroupId = action['targetGroupId'] as String?;
          
          if (targetGroupId != null) {
            drawingNotifier.applyGravityToGroup(targetGroupId);
          } else {
            // Apply to the most recently added group if no target is specified
            final currentStrokes = ref.read(drawingProvider).strokes;
            if (currentStrokes.isNotEmpty) {
              final lastGroupId = currentStrokes.last.groupId;
              if (lastGroupId != null) {
                drawingNotifier.applyGravityToGroup(lastGroupId);
              }
            }
          }
          objectsUpdated++; // Prevent fallback
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
            if (colorStr.toLowerCase() == 'red') color = Colors.red;
            else if (colorStr.toLowerCase() == 'blue') color = Colors.blue;
            else if (colorStr.toLowerCase() == 'green') color = Colors.green;
            else if (colorStr.toLowerCase() == 'yellow') color = Colors.yellow;
            else if (colorStr.toLowerCase() == 'black') color = Colors.black;
            else if (colorStr.toLowerCase() == 'white') color = Colors.white;
            else color = Color(int.parse(colorStr));
          }
        } catch (_) {}

        // --- ADAPTABILITY LOGIC ---
        final bgColor = ref.read(drawingProvider).canvasBackgroundColor ?? Colors.white;
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
        final shapeFilled = (action['isFilled'] ?? action['filled']) as bool? ?? false;
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
              isFilled: shapeFilled,
            ),
          );
        } else if (type == 'draw_circle') {
          final center = action['center'] as List?;
          if (center == null || center.length < 2) continue;
          final p = mapPoint(center[0].toDouble(), center[1].toDouble());
          final radius = ((action['radius'] as num).toDouble() / 2.0) * scale;
          newStrokes.add(
            AiStrokeGenerator.generateCircle(p.dx, p.dy, radius, color, size, isFilled: shapeFilled),
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
            AiStrokeGenerator.generatePolygon(mappedPoints, color, size, isFilled: shapeFilled),
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
            
            final groupId = '${compositeName}_${DateTime.now().millisecondsSinceEpoch}';
            
            void parsePartsList(List partsList) {
              for (var part in partsList) {
                if (part is! Map) continue;
                final partType = part['type'] as String?;
                final partColorHex = part['color'] as String?;
                Color partColor = color; // default to outer color
                if (partColorHex != null) {
                  try {
                    partColor = Color(int.parse(partColorHex.replaceFirst('0x', '').replaceFirst('#', ''), radix: 16) + 0xFF000000);
                  } catch (_) {}
                }
                final isFilled = part['isFilled'] as bool? ?? false;
                
                if (partType == 'circle') {
                   final cx = (part['cx'] as num?)?.toDouble() ?? 0.0;
                   final cy = (part['cy'] as num?)?.toDouble() ?? 0.0;
                   final r = (part['r'] as num?)?.toDouble() ?? 20.0;
                   final stroke = AiStrokeGenerator.generateCircle(
                     basePos.dx + (cx * overallScale), basePos.dy + (cy * overallScale), r * overallScale, partColor, 2.0 * viewScale
                   );
                   newStrokes.add(stroke.copyWith(groupId: groupId, name: part['name']?.toString(), isFilled: isFilled, semanticMeaning: compositeName));
                } else if (partType == 'ellipse') {
                   final cx = (part['cx'] as num?)?.toDouble() ?? 0.0;
                   final cy = (part['cy'] as num?)?.toDouble() ?? 0.0;
                   final rx = (part['rx'] as num?)?.toDouble() ?? 30.0;
                   final ry = (part['ry'] as num?)?.toDouble() ?? 20.0;
                   final stroke = AiStrokeGenerator.generateEllipse(
                     basePos.dx + (cx * overallScale), basePos.dy + (cy * overallScale), rx * overallScale, ry * overallScale, partColor, 2.0 * viewScale
                   );
                   newStrokes.add(stroke.copyWith(groupId: groupId, name: part['name']?.toString(), isFilled: isFilled, semanticMeaning: compositeName));
                } else if (partType == 'rect') {
                   final px = (part['x'] as num?)?.toDouble() ?? 0.0;
                   final py = (part['y'] as num?)?.toDouble() ?? 0.0;
                   final pw = (part['w'] as num?)?.toDouble() ?? 40.0;
                   final ph = (part['h'] as num?)?.toDouble() ?? 40.0;
                   final stroke = AiStrokeGenerator.generateRect(
                     basePos.dx + (px * overallScale), basePos.dy + (py * overallScale), pw * overallScale, ph * overallScale, partColor, 2.0 * viewScale
                   );
                   newStrokes.add(stroke.copyWith(groupId: groupId, name: part['name']?.toString(), isFilled: isFilled, semanticMeaning: compositeName));
                } else if (partType == 'line') {
                   final x1 = (part['x1'] as num?)?.toDouble() ?? 0.0;
                   final y1 = (part['y1'] as num?)?.toDouble() ?? 0.0;
                   final x2 = (part['x2'] as num?)?.toDouble() ?? 0.0;
                   final y2 = (part['y2'] as num?)?.toDouble() ?? 0.0;
                   newStrokes.add(Stroke(
                     groupId: groupId, name: part['name']?.toString(), semanticMeaning: compositeName,
                     points: [Offset(basePos.dx + (x1 * overallScale), basePos.dy + (y1 * overallScale)), Offset(basePos.dx + (x2 * overallScale), basePos.dy + (y2 * overallScale))],
                     color: partColor, size: 2.0 * viewScale, toolType: ToolType.pen,
                   ));
                } else if (partType == 'bezier_curve') {
                   final p0 = part['p0'] as List? ?? [0,0];
                   final p1 = part['p1'] as List? ?? [0,0];
                   final p2 = part['p2'] as List? ?? [0,0];
                   final p3 = part['p3'] as List? ?? [0,0];
                   double safeNum(dynamic l, int idx) => (l is List && l.length > idx && l[idx] != null) ? (l[idx] as num).toDouble() : 0.0;
                   final stroke = AiStrokeGenerator.generateBezierCurve(
                     Offset(basePos.dx + (safeNum(p0,0) * overallScale), basePos.dy + (safeNum(p0,1) * overallScale)),
                     Offset(basePos.dx + (safeNum(p1,0) * overallScale), basePos.dy + (safeNum(p1,1) * overallScale)),
                     Offset(basePos.dx + (safeNum(p2,0) * overallScale), basePos.dy + (safeNum(p2,1) * overallScale)),
                     Offset(basePos.dx + (safeNum(p3,0) * overallScale), basePos.dy + (safeNum(p3,1) * overallScale)),
                     partColor, 2.0 * viewScale
                   );
                   newStrokes.add(stroke.copyWith(groupId: groupId, name: part['name']?.toString(), semanticMeaning: compositeName));
                } else if (partType == 'organic_path') {
                   final bPts = part['base_points'] as List? ?? [[0,0]];
                   final nl = (part['noise_level'] as num?)?.toDouble() ?? 3.0;
                   double safeNum(dynamic l, int idx) => (l is List && l.length > idx && l[idx] != null) ? (l[idx] as num).toDouble() : 0.0;
                   List<Offset> mapped = bPts.map((pt) => Offset(basePos.dx + (safeNum(pt,0) * overallScale), basePos.dy + (safeNum(pt,1) * overallScale))).toList();
                   final stroke = AiStrokeGenerator.generateOrganicPath(mapped, nl * overallScale, partColor, 2.0 * viewScale);
                   newStrokes.add(stroke.copyWith(groupId: groupId, name: part['name']?.toString(), isFilled: isFilled, semanticMeaning: compositeName));
                } else if (partType == 'polygon') {
                   final pts = part['points'] as List? ?? [[0,0]];
                   double safeNum(dynamic l, int idx) => (l is List && l.length > idx && l[idx] != null) ? (l[idx] as num).toDouble() : 0.0;
                   List<Offset> mapped = pts.map((pt) => Offset(basePos.dx + (safeNum(pt,0) * overallScale), basePos.dy + (safeNum(pt,1) * overallScale))).toList();
                   final stroke = AiStrokeGenerator.generatePolygon(mapped, partColor, 2.0 * viewScale);
                   newStrokes.add(stroke.copyWith(groupId: groupId, name: part['name']?.toString(), isFilled: isFilled, semanticMeaning: compositeName));
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
            final p = targetTopLeft ?? (pos != null && pos.length >= 2 ? mapPoint(pos[0].toDouble(), pos[1].toDouble()) : mapPoint(100.0, 100.0));
            final scale = inverse.getMaxScaleOnAxis();

            final svgScale = (action['scale'] as num?)?.toDouble() ?? 1.0;
            final isFilled = (action['isFilled'] ?? action['filled']) as bool? ?? false;

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

          final p = targetTopLeft ?? (pos != null && pos.length >= 2 ? mapPoint(pos[0].toDouble(), pos[1].toDouble()) : mapPoint(100.0, 100.0));
          final scale = inverse.getMaxScaleOnAxis();

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

          // Collision avoidance via radial search (bypassed if overlap is requested)
          final overlap = action['overlap'] == true || action['allowOverlap'] == true;
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
          bool hasCollision = !overlap;

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
            finalX,
            finalY,
            size * 2.0, // Pass the actual size parameter instead of hardcoded 100
          );

          final isFilled = (action['isFilled'] ?? action['filled']) as bool? ?? true;
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

          final p = targetTopLeft ?? mapPoint(rawX, rawY);
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
        } else if (type == 'draw_wire') {
          final start = action['start'] as List?;
          final end = action['end'] as List?;
          if (start != null && end != null && start.length >= 2 && end.length >= 2) {
            final p1 = mapPoint(start[0].toDouble(), start[1].toDouble());
            final p2 = mapPoint(end[0].toDouble(), end[1].toDouble());
            newStrokes.add(Stroke(
              points: [p1, p2],
              color: color,
              size: size * scale,
              toolType: ToolType.wire,
            ));
          }
        } else if (type == 'draw_portal') {
          final pos = action['position'] as List?;
          final r = (action['radius'] as num?)?.toDouble() ?? 40.0;
          if (pos != null && pos.length >= 2) {
            final p = mapPoint(pos[0].toDouble(), pos[1].toDouble());
            newStrokes.add(Stroke(
              points: [p, Offset(p.dx + r*2, p.dy + r*2)],
              color: color,
              size: size * scale,
              toolType: ToolType.portal,
            ));
          }
        } else if (type == 'insert_chemistry') {
          final formula = action['formula'] as String?;
          List? pos = action['position'] as List?;
          if (formula != null) {
            final rawP = targetTopLeft ?? (pos != null && pos.length >= 2 ? mapPoint(pos[0].toDouble(), pos[1].toDouble()) : mapPoint(100.0, 100.0));
            final scale = inverse.getMaxScaleOnAxis();
            
            Offset p = rawP;
            // Prevent stacking if AI generated multiple items at the exact same coordinate
            if (lastPlacedPos != null && (p.dx - lastPlacedPos!.dx).abs() < 5 && (p.dy - lastPlacedPos!.dy).abs() < 5) {
                p = Offset(lastPlacedPos!.dx + 380.0 * scale, lastPlacedPos!.dy);
                if (p.dx > (targetTopLeft?.dx ?? mapPoint(100.0, 100.0).dx) + 1500.0 * scale) { // wrap to next row
                   p = Offset(rawP.dx, lastPlacedPos!.dy + 380.0 * scale);
                }
            }
            lastPlacedPos = p;

            // NEW: fetch molecule via ChemistryService (plain JSON/SDF text —
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
                chemMolecule: mol, // already loaded — no spinner needed
                text: 'chemistry', // kept for scene graph semantic tag
              ),
            );
          }
        } else if (type == 'generate_image') {
          final prompt = action['prompt'] as String?;
          List? pos = action['position'] as List?;
          if (prompt != null) {
            final rawP = targetTopLeft ?? (pos != null && pos.length >= 2 ? mapPoint(pos[0].toDouble(), pos[1].toDouble()) : mapPoint(100.0, 100.0));
            final scale = inverse.getMaxScaleOnAxis();

            Offset p = rawP;
            // Prevent stacking if AI generated multiple items at the exact same coordinate
            if (lastPlacedPos != null && (p.dx - lastPlacedPos!.dx).abs() < 5 && (p.dy - lastPlacedPos!.dy).abs() < 5) {
                p = Offset(lastPlacedPos!.dx + 550.0 * scale, lastPlacedPos!.dy);
                if (p.dx > (targetTopLeft?.dx ?? mapPoint(100.0, 100.0).dx) + 1500.0 * scale) { // wrap to next row
                   p = Offset(rawP.dx, lastPlacedPos!.dy + 550.0 * scale);
                }
            }
            lastPlacedPos = p;

            final seed = DateTime.now().millisecondsSinceEpoch;
            final url =
                'https://vinciboard-alpha.vercel.app/api/image?prompt=${Uri.encodeComponent(prompt)}&seed=$seed&width=512&height=512';

            final response = await http.get(Uri.parse(url));
            if (response.statusCode != 200) {
              throw Exception('Image generation failed: ${response.statusCode}');
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
          final p = targetTopLeft ?? mapPoint(100.0, (internalSafeY ?? 100.0) + 100.0);
          newStrokes.add(Stroke(
            points: [p],
            color: Colors.red,
            size: 1.0,
            toolType: ToolType.pen,
            text: "🚨 FAILED: $type\nError: $e",
          ));
          // Advance safeY so next fallback stroke doesn't overlap this one
          internalSafeY = (internalSafeY ?? 100.0) + 150.0;
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

    // INTERCEPT removed: The AI is now 'smart' enough to handle its own spatial reasoning based on the updated System Note.
    // It will use targetTopLeft for new chat responses, but original coordinates for object modifications.
    /*
    if (newStrokes.isNotEmpty && targetTopLeft != null) {
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
        final currentTopLeft = Offset(minX, minY);
        final shift = targetTopLeft - currentTopLeft;
        
        for (int i = 0; i < newStrokes.length; i++) {
          final s = newStrokes[i];
          final shiftedPoints = s.points.map((p) => p + shift).toList();
          newStrokes[i] = s.copyWith(points: shiftedPoints);
        }
      }
    }
    */

    double? finalMaxY;
    if (newStrokes.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
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
        
        finalMaxY = maxY;
        
        // --- COGNITIVE SPATIAL OS: Graph Registration ---
        final spatialRegistry = ref.read(spatialRegistryProvider.notifier);
        final parentId = ref.read(drawingProvider).selectedStrokes.isNotEmpty ? ref.read(drawingProvider).selectedStrokes.first.groupId : null;
        
        final node = SpatialNode(
           groupId: newStrokes.first.groupId ?? 'generated_${DateTime.now().millisecondsSinceEpoch}',
           clusterId: parentId ?? 'root_${DateTime.now().millisecondsSinceEpoch}',
           parentId: parentId,
           bounds: bounds,
           depth: parentId != null ? (spatialRegistry.getNode(parentId)?.depth ?? 0) + 1 : 0,
           orderIndex: 0,
           semanticType: parentId == null ? SemanticType.root : SemanticType.expansion,
        );
        spatialRegistry.registerNode(node);
        
        // --- COGNITIVE SPATIAL OS: Camera Perception ---
        final isRoot = parentId == null;
        final intent = SemanticCameraIntelligence.determineIntent(
          userState: UserIntentState.follow, // User waiting for AI
          nodeDepth: node.depth,
          isRoot: isRoot,
          isFullyOffscreen: true, // We assume true for new AI generations to trigger softGuide
        );
        EventBus().publish(EventType.aiTaskCompleted, {'intent': intent});
      }
    } else if (objectsAdded > 0 || objectsUpdated > 0) {
       // Also focus if we inserted widgets or images directly
       EventBus().publish(EventType.aiTaskCompleted, {'intent': CameraIntent.userAssistedFocus});
    }

    if (newStrokes.isNotEmpty || objectsAdded > 0) {
      drawingNotifier.setAiStatus(null);
      widget.onDrawStart?.call();
    }

    if (newStrokes.isNotEmpty) {
      objectsAdded += newStrokes.length;
      if (isAnimateFrame) {
        drawingNotifier.addStrokes(newStrokes);
      } else {
        await drawingNotifier.animateStrokes(newStrokes);
      }
    }

    if (mounted && (newStrokes.isNotEmpty || objectsAdded > 0)) {
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
    if (_isTyping) {
      return const SizedBox.shrink();
    }

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final messages = ref.watch(aiChatProvider).messages;

    return Container(
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
              // Header with Tutor Mode Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vinci Agent',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.black54, size: 20),
                      onSelected: (value) {
                        if (value == 'clear') {
                          ref.read(aiChatProvider.notifier).clear();
                        } else if (value.startsWith('mode_')) {
                          final modeName = value.split('_')[1];
                          final mode = AiTutorMode.values.firstWhere((m) => m.name == modeName);
                          setState(() => _selectedTutorMode = mode);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Clear Chat', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        ...AiTutorMode.values.map((mode) => PopupMenuItem(
                          value: 'mode_${mode.name}',
                          child: Row(
                            children: [
                              Icon(
                                _selectedTutorMode == mode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 20,
                                color: _selectedTutorMode == mode ? Colors.blueAccent : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text('${mode.name.toUpperCase()} Mode'),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54, size: 20),
                      onPressed: () => widget.onClose?.call(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (msg['image'] != null && msg['image'] is Uint8List)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      msg['image'] as Uint8List,
                                      width: 150,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              if (msg['text']?.toString().isNotEmpty ?? false)
                                Text(
                                  msg['text']!.toString(),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                            ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_attachedImage != null)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: MemoryImage(_attachedImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -10,
                            top: -10,
                            child: GestureDetector(
                              onTap: () => setState(() => _attachedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                                  final isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                                                  HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
                                  if (!isShift) {
                                    Future.microtask(_sendMessage);
                                    return KeyEventResult.handled;
                                  }
                                }
                                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyV) {
                                  final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                                                 HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight) ||
                                                 HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaLeft) ||
                                                 HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaRight);
                                  if (isCtrl) {
                                    Pasteboard.image.then((bytes) {
                                      if (bytes != null) {
                                        setState(() {
                                          _attachedImage = bytes;
                                        });
                                      }
                                    });
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: _textController,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  prefixIcon: IconButton(
                                    icon: const Icon(Icons.attach_file, color: Colors.black54),
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final file = await picker.pickImage(source: ImageSource.gallery);
                                      if (file != null) {
                                        final bytes = await file.readAsBytes();
                                        setState(() {
                                          _attachedImage = bytes;
                                        });
                                      }
                                    },
                                  ),
                                  hintText: 'Ask Vinci to do something',
                                  hintStyle: const TextStyle(color: Colors.black54),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  suffixIcon: _textController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close, size: 18, color: Colors.black54),
                                          onPressed: () {
                                            _textController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _isTyping ? Colors.red.shade600 : Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isTyping ? Icons.stop : Icons.arrow_upward,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _isTyping 
                            ? () {
                                setState(() {
                                  _cancelRequested = true;
                                  AiAgentService.cancelRequest();
                                });
                                if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
                                  _cancelCompleter!.complete("Cancelled by user");
                                }
                              }
                            : _sendMessage,
                        tooltip: _isTyping ? 'Stop Generation' : 'Send',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
