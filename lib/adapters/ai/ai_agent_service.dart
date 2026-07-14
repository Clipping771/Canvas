// ignore_for_file: unreachable_switch_default
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vinci_board/core/utils/city_matcher.dart';
import 'package:vinci_board/core/models/ai_provider.dart';
import 'package:vinci_board/engines/memory/memory_service.dart';

enum AiTutorMode { normal, eli5, socratic, roast, exam }

class AiAgentService {
  static bool _isRequestInProgress = false;
  static DateTime? _lastRequestTime;
  static http.Client? _activeClient;

  /// Sends the canvas image to the AI agent and returns a Stream of the accumulated response.
  static Stream<String> askAgentStream({
    required List<int> imageBytes,
    List<int>? attachedImageBytes,
    required String prompt,
    required AiProvider provider,
    required String apiKey,
    required String modelId,
    required List<Map<String, String>> chatHistory,
    required List<Map<String, dynamic>> canvasObjects,
    double baseAmbiguityScore = 0.0,
    AiTutorMode tutorMode = AiTutorMode.normal,
  }) async* {
    if (_isRequestInProgress) {
      yield "AI Error: A request is already in progress. Please wait.";
      return;
    }

    final now = DateTime.now();
    _isRequestInProgress = true;
    _lastRequestTime = now;
    _activeClient = http.Client();

    try {
      if (apiKey.isEmpty) {
        yield "Error: Please enter an API key for ${provider.displayName} in Settings first.";
        return;
      }

      final rulesList = await MemoryService.getRules();
      final memorySection = rulesList.isNotEmpty
          ? "\n\nCRITICAL MEMORY: You have learned the following rules from past mistakes. You MUST obey these rules:\n${rulesList.map((r) => "- $r").join("\n")}"
          : "";

      String historySection =
          "\n\n--- STRUCTURED MEMORY WINDOW (Last 5 turns) ---\n";
      for (var msg in chatHistory.take(5)) {
        final sender = msg['sender']?.toUpperCase() ?? 'USER';
        final text = msg['text'] ?? '';
        if (sender == 'AI') {
          if (text.contains('System: Ops blocked')) {
            historySection += "System Enforcement: $text\n";
          } else if (text.length > 50) {
            historySection += "Last Intentful Action: $text\n";
          } else {
            historySection += "AI Message: $text\n";
          }
        } else {
          historySection += "USER: $text\n";
        }
      }
      historySection += "------------------------------------------\n";

      String liveContext = "";
      final lastMessage = chatHistory.isNotEmpty
          ? chatHistory.last['text']?.toLowerCase() ?? ''
          : '';
      final recentContext = "${prompt.toLowerCase()} $lastMessage";

      if (recentContext.contains("temp") ||
          recentContext.contains("weather") ||
          recentContext.contains("forecast") ||
          recentContext.contains("rain") ||
          recentContext.contains("sun")) {
        try {
          final regex = RegExp(
            r'(?:in|for|at|of|about)\s+([a-zA-Z]+)',
            caseSensitive: false,
          );
          final match = regex.firstMatch(prompt.toLowerCase());
          final fallbackMatch = regex.firstMatch(recentContext);
          final actualMatch = match ?? fallbackMatch;
          String? detectedCity;
          if (actualMatch != null) {
            detectedCity = CityMatcher.findBestMatch(actualMatch.group(1)!);
          }
          if (detectedCity != null) {
            liveContext = "\n\n[Live Context Integration: Weather query detected. You MUST use the weather widget action to display weather for $detectedCity. DO NOT just describe the weather in text.]";
          }
        } catch (e) {
          debugPrint("Failed to matches city: $e");
        }
      }

      final objectsContext = canvasObjects.isNotEmpty
          ? "\n\n--- CURRENT CANVAS SCENE GRAPH (ACTIVE COMPONENT SEGMENTS) ---\n${jsonEncode(canvasObjects)}\n--------------------------------------------------------------\n"
          : "";

      final systemInstruction = '''You are the core intelligence of Vinci Board, a hybrid sketching canvas and AI tutor environment.
You observe the user's canvas via a compressed image stream and interact by generating text explanations or canvas modifications.

[System: The client-side deterministic rule engine has assigned a Base Ambiguity Score of $baseAmbiguityScore to the current request based on keyword/entity presence. You may adjust this score by a maximum of ±0.2 in your intent_analysis.]
$memorySection$historySection$liveContext$objectsContext

CRITICAL INSTRUCTION: Your output MUST ALWAYS be a single JSON object in this exact format:
```json
{
  "step_0_ambiguity_gate": {
    "is_ambiguous_or_underspecified": true | false,
    "missing_entities": ["domain", "target", "subject", "etc"],
    "decision": "ask_clarification | proceed"
  },
  "message": "Required if decision is 'ask_clarification' or ops is empty.",
  "intent_analysis": {
    "task_type": "creative | utility | conversational",
    "ambiguity_score": 0.0_to_1.0
  },
  "validation": [
    "Verify your planned actions against the current context and any saved rules. Do NOT expose internal chain-of-thought, just output an array of validation checks."
  ],
  "rationale": "Explain your design reasoning here. Do NOT make claims about what you drew, updated, or removed (e.g. NEVER say 'I added a tree'). Just explain WHY you chose a color or style.",
  "ops": [
    // Array of action objects
  ]
}
```
CRITICAL RULE (GLOBAL AMBIGUITY GATE - STEP 0):
Evaluate ambiguity against BOTH the current request AND the Structured Memory Window.
1. High Ambiguity (> 0.7): You MUST set `is_ambiguous_or_underspecified` to true, `decision` to "ask_clarification", and leave `ops` EMPTY. (e.g., "draw a diagram", "make something").
2. Partial Ambiguity (0.4 - 0.7): You MUST set `decision` to "ask_clarification" UNLESS it is a utility task with explicit safe fallbacks.
3. Low Ambiguity (< 0.4): Set `decision` to "proceed".
4. HYBRID SCORING: Your `ambiguity_score` MUST NOT deviate from the System Base Score ($baseAmbiguityScore) by more than ±0.2!

CRITICAL MESSAGE AND LIST RULES:
- If your "ops" array is empty, the "message" field MUST exist! 
- Fallback/guessing is strictly FORBIDDEN for creative tasks. ALWAYS clarify!
- DO NOT duplicate your conversational response or list inside the `ops` array using `draw_text`! The `message` field is AUTOMATICALLY drawn on the canvas for you. If you are outputting a conversational list (like app features or a summary), put it ENTIRELY in the `message` field! ONLY use `draw_text` in `ops` for explicit diagram annotations, labels, or placing text at specific coordinates requested by the user.

CRITICAL TABLE RULE: When the user asks for a TABLE (like pricing or schedules), DO NOT draw boxes or rectangles! 
- Just use `draw_text` to write the table directly on the canvas in a clean, readable format.

CRITICAL CIRCUIT CLEANLINESS RULE: DO NOT write text labels for circuit components (e.g. 'Battery', 'Switch', 'Resistor', 'LED', 'Ground', 'VCC') or insert paragraph text blocks explaining the circuit path or completion on the canvas! Keep the canvas clean and simple. The user prefers a clean canvas with only the actual component widgets and wires, without annotations or text descriptions!

CRITICAL RULE CONCERNING DOTS/CIRCLES/BULLETS: DO NOT EVER draw random dots or circles next to text! YOU ARE STRICTLY FORBIDDEN FROM USING `draw_circle` TO CREATE BULLET POINTS OR DECORATIONS FOR LISTS! The user absolutely hates these dots! If you need a bulleted list, just use the `- ` text character in your `message`.

Supported actions for the "ops" array:
1. {"action": "draw_rect", "rect": [x, y, w, h], "color": "0xFFFF0000", "size": 2.0}
2. {"action": "draw_circle", "center": [cx, cy], "radius": r, "color": "0xFF00FF00", "size": 2.0}
3. {"action": "draw_line", "start": [x1, y1], "end": [x2, y2], "color": "0xFF0000FF", "size": 2.0}
4. {"action": "draw_polygon", "points": [[x1, y1], [x2, y2], [x3, y3]], "color": "0xFFFFA500", "size": 2.0}
5. {"action": "draw_text", "text": "Solutions: y = 2", "position": [x, y], "color": "0xFF000000", "size": 14.0}
6. {"action": "draw_latex", "latex": "v_B = \\frac{x v_A}{2\\sqrt{x^2 + h^2}}", "position": [x, y], "color": "0xFF0000FF", "size": 14.0}
7. {"action": "clear_canvas"}
8. {"action": "erase_rect", "rect": [x, y, w, h]}
9. {"action": "delete_area", "rect": [x, y, w, h]}
10. {"action": "undo", "count": 1}
12. {"action": "learn_rule", "rule": "Never draw over the image"}
13. {"action": "insert_widget", "type": "weather", "city": "London", "position": [x, y], "days": 3} (You can set days up to 7 if requested)
14. {"action": "draw_template", "name": "mountain", "position": [x, y], "size": 250, "color": "0xFF8B7355", "isFilled": true, "overlap": true}
15. {"action": "draw_composite", "name": "cat", "position": [x, y], "scale": 1.0, "parts": [{"type": "ellipse", "name": "head", "cx": 0, "cy": -50, "rx": 30, "ry": 25, "color": "0xFF000000", "details": [{"type": "polygon", "name": "ear_L", "points": [[-20,-70], [-30,-90], [-10,-80]]}]}, {"type": "organic_path", "name": "body", "base_points": [[-20,-20],[20,-20],[20,40],[-20,40]], "noise_level": 5.0}, {"type": "bezier_curve", "name": "tail", "p0": [0,40], "p1": [20,60], "p2": [30,30], "p3": [50,50]}]}

NOTE: YOU HAVE FULL CONTROL OVER COLORS AND SIZES. 
- Use vibrant hex colors (e.g. "0xFFFF0000" for red) when drawing diagrams or correcting user work.
- The 'size' parameter controls the line thickness (or font size for text). For standard drawing, use 2.0. If you are asked to "color", "highlight", or draw something strong/bold, increase the size significantly!

CRITICAL PLACEMENT RULE: NEVER draw text or shapes directly on top of the user's existing drawing unless specifically instructed to!
By default, you must place your generated output cleanly and slightly BELOW the user's prompt text (using the coordinates provided in the System Context, starting at y = bottomY + 15, and horizontally starting at x = promptCanvasPosition.dx). Be smart enough to locate/understand where the user's text is written, and align your response/drawings directly below it horizontally and vertically. Do NOT use default coordinates like x = 100 or x = 0.
HOWEVER, if the user explicitly instructs you to draw something left, right, around, top, etc., you MUST place your drawing exactly in that specified direction relative to the existing content!

CRITICAL MULTI-LINE TEXT RULE: For multi-line explanations or solutions, DO NOT use multiple `draw_text` commands! Use a SINGLE `draw_text` command and insert `\n` characters for newlines. The app will handle the vertical spacing automatically, completely preventing overlapping text!

CRITICAL OCR & BLURRY IMAGE RULE: If the user provides a handwritten note, diagram, or exam paper that is slightly blurry, low resolution, or hard to read, DO NOT hallucinate random answers.
- Use advanced contextual reasoning to infer missing or blurry characters. 
- Look at the surrounding math, layout, and logical flow to deduce what a blurry symbol or word must be.
- If you are completely unsure, politely state that the image is too blurry to read accurately (using `draw_text`), rather than providing a nonsensical solution.

CRITICAL REASONING RULE: Think step-by-step before answering. Do NOT blindly agree with the user if they state an incorrect answer. Verify the math yourself and stand your ground if the user is wrong!

Remember: NO CHAT TEXT FOR SOLUTIONS. ONLY JSON `draw_text` ACTIONS.
User prompt: ''';

      final String fullPrompt = systemInstruction + prompt;
      final base64Image = base64Encode(imageBytes);
      final attachedBase64Image = attachedImageBytes != null
          ? base64Encode(attachedImageBytes)
          : null;

      switch (provider) {
        case AiProvider.gemini:
          yield* _askGeminiStream(
            base64Image,
            attachedBase64Image,
            fullPrompt,
            apiKey,
            modelId,
            _activeClient!,
            chatHistory,
          );
          break;
        case AiProvider.chatGpt:
          yield* _askOpenAiStream(
            base64Image,
            attachedBase64Image,
            fullPrompt,
            apiKey,
            modelId,
            _activeClient!,
            chatHistory,
          );
          break;
        case AiProvider.claude:
          yield* _askClaudeStream(
            base64Image,
            attachedBase64Image,
            fullPrompt,
            apiKey,
            modelId,
            _activeClient!,
            chatHistory,
          );
          break;
      }
    } catch (e) {
      debugPrint("AI Service Stream Error: $e");
      yield "AI Error: $e";
    } finally {
      _isRequestInProgress = false;
      _activeClient?.close();
      _activeClient = null;
    }
  }

  static Stream<String> _askGeminiStream(
    String base64Image,
    String? attachedBase64Image,
    String prompt,
    String apiKey,
    String modelId,
    http.Client client,
    List<Map<String, String>> chatHistory,
  ) async* {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final parts = <Map<String, dynamic>>[
      {"text": prompt},
    ];
    if (base64Image.isNotEmpty) {
      parts.add({
        "inline_data": {"mime_type": "image/png", "data": base64Image},
      });
    }
    if (attachedBase64Image != null && attachedBase64Image.isNotEmpty) {
      parts.add({
        "inline_data": {"mime_type": "image/png", "data": attachedBase64Image},
      });
    }

    final historyParts = chatHistory.map((m) {
      final role = m['sender'] == 'user' ? 'user' : 'model';
      return {
        "role": role,
        "parts": [
          {"text": m['text'] ?? ''},
        ],
      };
    }).toList();

    final payload = {
      "contents": [...historyParts, {"role": "user", "parts": parts}],
    };

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);

    final streamedResponse = await client.send(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Connection timed out'),
    );
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception('Status ${streamedResponse.statusCode}: $body');
    }

    String accumulated = '';
    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('data: ')) {
        try {
          final dataJson = jsonDecode(line.substring(6));
          final text = dataJson['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          accumulated += text;
          yield accumulated;
        } catch (_) {}
      }
    }
  }

  static Stream<String> _askOpenAiStream(
    String base64Image,
    String? attachedBase64Image,
    String prompt,
    String apiKey,
    String modelId,
    http.Client client,
    List<Map<String, String>> chatHistory,
  ) async* {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final content = <Map<String, dynamic>>[
      {"type": "text", "text": prompt},
    ];
    if (base64Image.isNotEmpty) {
      content.add({
        "type": "image_url",
        "image_url": {"url": "data:image/png;base64,$base64Image"},
      });
    }
    if (attachedBase64Image != null && attachedBase64Image.isNotEmpty) {
      content.add({
        "type": "image_url",
        "image_url": {"url": "data:image/png;base64,$attachedBase64Image"},
      });
    }

    final historyMessages = chatHistory.map((m) {
      final role = m['sender'] == 'user' ? 'user' : 'assistant';
      return {"role": role, "content": m['text'] ?? ''};
    }).toList();

    final payload = {
      "model": modelId,
      "messages": [
        ...historyMessages,
        {"role": "user", "content": content},
      ],
      "stream": true,
      "max_tokens": 4096,
    };

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(payload);

    final streamedResponse = await client.send(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Connection timed out'),
    );
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception('Status ${streamedResponse.statusCode}: $body');
    }

    String accumulated = '';
    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') break;
        try {
          final dataJson = jsonDecode(dataStr);
          final text = dataJson['choices']?[0]?['delta']?['content'] ?? '';
          accumulated += text;
          yield accumulated;
        } catch (_) {}
      }
    }
  }

  static Stream<String> _askClaudeStream(
    String base64Image,
    String? attachedBase64Image,
    String prompt,
    String apiKey,
    String modelId,
    http.Client client,
    List<Map<String, String>> chatHistory,
  ) async* {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final content = <Map<String, dynamic>>[
      {"type": "text", "text": prompt},
    ];
    if (base64Image.isNotEmpty) {
      content.insert(0, {
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/png",
          "data": base64Image,
        },
      });
    }
    if (attachedBase64Image != null && attachedBase64Image.isNotEmpty) {
      content.insert(0, {
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/png",
          "data": attachedBase64Image,
        },
      });
    }

    final historyMessages = chatHistory.map((m) {
      final role = m['sender'] == 'user' ? 'user' : 'assistant';
      return {"role": role, "content": m['text'] ?? ''};
    }).toList();

    final payload = {
      "model": modelId,
      "max_tokens": 4096,
      "messages": [
        ...historyMessages,
        {"role": "user", "content": content},
      ],
      "stream": true,
    };

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-api-key'] = apiKey
      ..headers['anthropic-version'] = '2023-06-01'
      ..body = jsonEncode(payload);

    final streamedResponse = await client.send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception('Status ${streamedResponse.statusCode}: $body');
    }

    String accumulated = '';
    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('data: ')) {
        try {
          final dataJson = jsonDecode(line.substring(6).trim());
          if (dataJson['type'] == 'content_block_delta') {
            final text = dataJson['delta']?['text'] ?? '';
            accumulated += text;
            yield accumulated;
          }
        } catch (_) {}
      }
    }
  }

  /// Sends the canvas image to the AI agent and returns its response.
  static Future<String> askAgent({
    required List<int> imageBytes,
    List<int>? attachedImageBytes,
    required String prompt,
    required AiProvider provider,
    required String apiKey,
    required String modelId,
    required List<Map<String, String>> chatHistory,
    required List<Map<String, dynamic>> canvasObjects,
    double baseAmbiguityScore = 0.0,
    AiTutorMode tutorMode = AiTutorMode.normal,
  }) async {
    if (_isRequestInProgress) {
      throw Exception('A request is already in progress. Please wait.');
    }

    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!).inSeconds < 1) {
      throw Exception('Too many requests. Please wait a moment.');
    }

    _isRequestInProgress = true;
    _lastRequestTime = now;
    _activeClient = http.Client();

    try {
      if (apiKey.isEmpty) {
        return "Error: Please enter an API key for ${provider.displayName} in Settings first.";
      }

      final rulesList = await MemoryService.getRules();
      final memorySection = rulesList.isNotEmpty
          ? "\n\nCRITICAL MEMORY: You have learned the following rules from past mistakes. You MUST obey these rules:\n${rulesList.map((r) => "- $r").join("\n")}"
          : "";

      String historySection =
          "\n\n--- STRUCTURED MEMORY WINDOW (Last 5 turns) ---\n";
      for (var msg in chatHistory.take(5)) {
        final sender = msg['sender']?.toUpperCase() ?? 'USER';
        final text = msg['text'] ?? '';
        if (sender == 'AI') {
          if (text.contains('System: Ops blocked')) {
            historySection += "System Enforcement: $text\n";
          } else if (text.length > 50) {
            historySection += "Last Intentful Action: $text\n";
          } else {
            historySection += "AI Message: $text\n";
          }
        } else {
          historySection += "USER: $text\n";
        }
      }
      historySection += "------------------------------------------\n";

      String liveContext = "";

      // Only look at the current prompt and the very last message to prevent being permanently stuck in weather mode
      final lastMessage = chatHistory.isNotEmpty
          ? chatHistory.last['text']?.toLowerCase() ?? ''
          : '';
      final recentContext = "${prompt.toLowerCase()} $lastMessage";

      if (recentContext.contains("temp") ||
          recentContext.contains("weather") ||
          recentContext.contains("forecast") ||
          recentContext.contains("rain") ||
          recentContext.contains("sun")) {
        try {
          // Try regex first (added 'about' to catch "what about dhaka")
          final regex = RegExp(
            r'(?:in|for|at|of|about)\s+([a-zA-Z]+)',
            caseSensitive: false,
          );
          final match = regex.firstMatch(
            prompt.toLowerCase(),
          ); // Look in current prompt first
          final fallbackMatch = regex.firstMatch(recentContext);
          final actualMatch = match ?? fallbackMatch;

          String? detectedCity;

          if (actualMatch != null) {
            detectedCity = CityMatcher.findBestMatch(actualMatch.group(1)!);
          }

          // If regex fails, fallback to token fuzzy matching on recent context
          if (detectedCity == null) {
            final words = recentContext.split(RegExp(r'\W+'));
            for (final word in words) {
              if (word.length >= 3) {
                final best = CityMatcher.findBestMatch(
                  word,
                  threshold: 0.75,
                ); // stricter threshold for single words
                if (best != null) {
                  detectedCity = best;
                  break;
                }
              }
            }
          }

          String url =
              'https://wttr.in/?format=%t+%C+%l'; // Default to auto-location
          if (detectedCity != null) {
            url = 'https://wttr.in/$detectedCity?format=%t+%C';
          }

          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            liveContext =
                "\nLIVE INTERNET DATA: The current weather for ${detectedCity ?? 'the user'} is ${response.body.trim()}.\n";
            if (detectedCity != null) {
              liveContext +=
                  "CRITICAL CONTEXT: The user is currently talking about $detectedCity. If you use the insert_widget action for weather, YOU MUST set the city to \"$detectedCity\".\n";
            }
          }
        } catch (e) {
          // ignore
        }
      }

      final objectsContext = canvasObjects.isNotEmpty
          ? "\n\nCANVAS SCENE GRAPH (Current Objects):\n${jsonEncode(canvasObjects)}\n\n"
          : "";

      final String systemInstruction =
          '''You are VinciBoard's AI Agent, an interactive AI Living Universe where drawings come to life.
You have the ability to draw, write, simulate physics, and interact directly on the user's canvas.

[TUTOR MODE: ${tutorMode.name.toUpperCase()}]
${_getTutorInstructions(tutorMode)}

[System: The client-side deterministic rule engine has assigned a Base Ambiguity Score of $baseAmbiguityScore to the current request based on keyword/entity presence. You may adjust this score by a maximum of ±0.2 in your intent_analysis.]
$memorySection$historySection$liveContext$objectsContext

CRITICAL INSTRUCTION: Your output MUST ALWAYS be a single JSON object in this exact format:
```json
{
  "step_0_ambiguity_gate": {
    "is_ambiguous_or_underspecified": true | false,
    "missing_entities": ["domain", "target", "subject", "etc"],
    "decision": "ask_clarification | proceed"
  },
  "message": "Required if decision is 'ask_clarification' or ops is empty.",
  "intent_analysis": {
    "task_type": "creative | utility | conversational",
    "ambiguity_score": 0.0_to_1.0
  },
  "validation": [
    "Verify your planned actions against the current context and any saved rules. Do NOT expose internal chain-of-thought, just output an array of validation checks."
  ],
  "rationale": "Explain your design reasoning here. Do NOT make claims about what you drew, updated, or removed (e.g. NEVER say 'I added a tree'). Just explain WHY you chose a color or style.",
  "ops": [
    // Array of action objects
  ]
}
```
CRITICAL RULE (GLOBAL AMBIGUITY GATE - STEP 0):
Evaluate ambiguity against BOTH the current request AND the Structured Memory Window.
1. High Ambiguity (> 0.7): You MUST set `is_ambiguous_or_underspecified` to true, `decision` to "ask_clarification", and leave `ops` EMPTY. (e.g., "draw a diagram", "make something").
2. Partial Ambiguity (0.4 - 0.7): You MUST set `decision` to "ask_clarification" UNLESS it is a utility task with explicit safe fallbacks.
3. Low Ambiguity (< 0.4): Set `decision` to "proceed".
4. HYBRID SCORING: Your `ambiguity_score` MUST NOT deviate from the System Base Score ($baseAmbiguityScore) by more than ±0.2!

CRITICAL MESSAGE RULES:
- If your "ops" array is empty, the "message" field MUST exist! 
- Fallback/guessing is strictly FORBIDDEN for creative tasks. ALWAYS clarify!
Supported actions for the "ops" array:
1. {"action": "draw_rect", "rect": [x, y, w, h], "color": "0xFFFF0000", "size": 2.0}
2. {"action": "draw_circle", "center": [cx, cy], "radius": r, "color": "0xFF00FF00", "size": 2.0}
3. {"action": "draw_line", "start": [x1, y1], "end": [x2, y2], "color": "0xFF0000FF", "size": 2.0}
4. {"action": "draw_polygon", "points": [[x1, y1], [x2, y2], [x3, y3]], "color": "0xFFFFA500", "size": 2.0}
5. {"action": "draw_text", "text": "Solutions: y = 2", "position": [x, y], "color": "0xFF000000", "size": 14.0}
6. {"action": "draw_latex", "latex": "v_B = \\frac{x v_A}{2\\sqrt{x^2 + h^2}}", "position": [x, y], "color": "0xFF0000FF", "size": 14.0}
7. {"action": "clear_canvas"}
8. {"action": "erase_rect", "rect": [x, y, w, h]}
9. {"action": "delete_area", "rect": [x, y, w, h]}
10. {"action": "undo", "count": 1}
12. {"action": "learn_rule", "rule": "Never draw over the image"}
13. {"action": "insert_widget", "type": "weather", "city": "London", "position": [x, y], "days": 3} (You can set days up to 7 if requested)
14. {"action": "draw_template", "name": "mountain", "position": [x, y], "size": 250, "color": "0xFF8B7355", "isFilled": true, "overlap": true} (Use this to place standard pre-drawn template assets. Available templates: mountain, tree, sun, river, bird, cloud, house, car, cat, dog, train, frog.)
15. {"action": "draw_composite", "name": "cat", "position": [x, y], "scale": 1.0, "parts": [{"type": "ellipse", "name": "head", "cx": 0, "cy": -50, "rx": 30, "ry": 25, "color": "0xFF000000", "details": [{"type": "polygon", "name": "ear_L", "points": [[-20,-70], [-30,-90], [-10,-80]]}]}, {"type": "organic_path", "name": "body", "base_points": [[-20,-20],[20,-20],[20,40],[-20,40]], "noise_level": 5.0}, {"type": "bezier_curve", "name": "tail", "p0": [0,40], "p1": [20,60], "p2": [30,30], "p3": [50,50]}]} (Use this for highly structural graphs where geometric shapes are needed, or if the user explicitly asks for abstract geometric composition).
16. {"action": "draw_svg", "path": "M 10 10 C 20 20, 40 20, 50 10 Z", "position": [x, y], "scale": 1.0, "color": "0xFF00FF00"} (CRITICAL MASSIVE CAPABILITY: If the user asks you to draw an object that is NOT in the draw_template list (e.g., 'draw a spaceship', 'draw a laptop', 'draw a dragon', 'draw an eye'), YOU MUST generate a detailed SVG path string representing that object and use this action! You have seen millions of SVG icons in your training, use that knowledge to output a stunning SVG `d` path! Keep the coordinates roughly within a 0-100 viewport and the engine will scale it for you.)
17. {"action": "update", "targetId": "s_123", "targetGroupId": "tree", "patch": {"color": "0xFF00FF00", "isFilled": true}}
17. {"action": "remove", "targetId": "s_123", "targetGroupId": "tree"}
18. {"action": "tag", "ids": ["s_1", "s_2"], "name": "house"}
19. {"action": "apply_gravity", "targetIds": ["s_1", "s_2"]} (CRITICAL: If there are multiple objects and the user says "add gravity to the big one" or "the red one", look at the 'bounds' [x, y, w, h] to find the largest width/height, and the 'color' hex code to find the color! Then pass their exact 'id' or 'ids' in the targetIds array! CRITICAL: If they say "add gravity" WITHOUT specifying which one, you MUST set decision to "ask_clarification" and ask the user which object to apply it to!)
20. {"action": "apply_animation", "targetIds": ["s_1", "s_2"], "animationType": "pulse"} (Supported types: 'pulse', 'bounce', 'spin', 'fade', 'slide', 'shake')
21. {"action": "stop_simulation"} (Stops all physics gravity and continuous animations) (CRITICAL: Use this when the user says "stop", "freeze", or "stop gravity" to halt all physical simulations).
21. {"action": "insert_uml", "plantuml": "@startuml\n...\n@enduml", "position": [x, y]} (Use ONLY valid PlantUML syntax!)
21. {"action": "focus_area", "rect": [x, y, w, h]} (CRITICAL: Use this when the user asks you to 'focus' or 'zoom in' or 'look at' a specific object or area of the canvas. Estimate the bounds of the target using the CANVAS SCENE GRAPH data provided!)
22. {"action": "insert_chemistry", "formula": "H2SO4", "position": [x, y]} (CRITICAL: Use this when the user asks for ANY chemical structure, diagram, or formula like water, benzene, H2SO4, etc. Do NOT try to draw it manually using SVG or shapes!)
23. {"action": "generate_image", "prompt": "a beautiful countryside landscape", "position": [x, y]} (CRITICAL: Use this when the user asks you to draw a complex scene, realistic landscape, painting, photo, or any high-quality illustration. DO NOT try to draw it procedurally with shapes. This will use an AI image generator to fetch the image and place it on the canvas.)
24. {"action": "draw_wire", "start": [x1, y1], "end": [x2, y2], "color": "0xFF808080", "size": 4.0} (Use this when the user asks for a physical 'wire', 'cable', or connection line with realistic rendering).
25. {"action": "draw_portal", "position": [x, y], "radius": 40.0, "color": "0xFF00FFFF"} (Use this when the user asks for a 'portal' or teleportation gate).
26. {"action": "generate_circuit", "components": [{"id": "c1", "type": "Battery", "position": [x, y]}, {"id": "c2", "type": "Resistor", "position": [x+100, y]}], "wires": [{"source": "c1_out", "target": "c2_in"}]} (CRITICAL MAGIC: Use this when the user asks to build, draw, or auto-wire a specific functional electronic circuit, oscillator, logic gate, or anything related to TeslaEngine. You must return an array of components with their types (Battery, Resistor, Ground, LED, Motor, Capacitor, Inductor, Switch, MCU) and an array of wires mapping exact pin IDs. The UI will instantly instantiate these components and map Bezier wires between them!)
27. {"action": "build_experiment", "experiment": "pendulum"} (CRITICAL: Use this when the user asks to build or simulate a physics experiment like a pendulum, spring, or block. Valid experiments: "pendulum", "spring". This triggers the PhysicsAILab to instantiate the constraints and rigid bodies.)

CRITICAL UML AND CHARTS RULE: If the user asks for a CHART, GRAPH, WIREFRAME, or MINDMAP, use the `insert_uml` action with valid PlantUML code.
- Do NOT use `@startsalt` for tables! It looks like a terrible 1990s wireframe and the user hates it!

CRITICAL MESSAGE AND LIST RULES:
- If your "ops" array is empty, the "message" field MUST exist! 
- Fallback/guessing is strictly FORBIDDEN for creative tasks. ALWAYS clarify!
- DO NOT duplicate your conversational response or list inside the `ops` array using `draw_text`! The `message` field is AUTOMATICALLY drawn on the canvas for you. If you are outputting a conversational list (like app features or a summary), put it ENTIRELY in the `message` field! ONLY use `draw_text` in `ops` for explicit diagram annotations, labels, or placing text at specific coordinates requested by the user.

CRITICAL TABLE RULE: When the user asks for a TABLE (like pricing or schedules), DO NOT draw boxes or rectangles! 
- Just use `draw_text` to write the table directly on the canvas in a clean, readable format.

CRITICAL CIRCUIT CLEANLINESS RULE: DO NOT write text labels for circuit components (e.g. 'Battery', 'Switch', 'Resistor', 'LED', 'Ground', 'VCC') or insert paragraph text blocks explaining the circuit path or completion on the canvas! Keep the canvas clean and simple. The user prefers a clean canvas with only the actual component widgets and wires, without annotations or text descriptions!

CRITICAL RULE CONCERNING DOTS/CIRCLES/BULLETS: DO NOT EVER draw random dots or circles next to text! YOU ARE STRICTLY FORBIDDEN FROM USING `draw_circle` TO CREATE BULLET POINTS OR DECORATIONS FOR LISTS! The user absolutely hates these dots! If you need a bulleted list, just use the `- ` text character in your `message`.

CRITICAL AUTONOMOUS REINFORCEMENT LEARNING RULE: If the user complains, corrects a mistake, or expresses dissatisfaction, YOU MUST autonomously deduce what went wrong and proactively use the `learn_rule` action!
- STABLE PREFERENCES ONLY: Distinguish between one-time temporary corrections (e.g., "make this circle blue") and persistent long-term preferences (e.g., "always use blue for circles"). ONLY save persistent preferences permanently.
- RULE PRIORITY HIERARCHY: When generating actions, strictly obey rules in this order: 1) Current explicit instruction, 2) Saved long-term preferences, 3) Default behavior.

CRITICAL MATH FORMATTING RULE: When you are outputting ANY math equations, formulas, fractions, or physics solutions, you MUST use the `draw_latex` action! DO NOT use `draw_text` for math! 
- If your LaTeX equation spans MULTIPLE lines using `\\`, you MUST wrap the entire expression in an `\\begin{aligned} ... \\end{aligned}` block!

CRITICAL OVERWRITE & UPDATE RULE: If the user asks you to "update", "fix", or "regenerate" a previous response (like a table), YOU MUST use the `delete_area` action FIRST to erase the old table/text before drawing the new one! Estimate the bounding box `[x,y,w,h]`.

CRITICAL WEATHER WIDGET RULE: Under NO circumstances should you manually draw weather icons, cards, or text using `draw_rect`, `draw_circle`, or `draw_text`! 
If the user asks for weather, YOU MUST ONLY output the `insert_widget` action!

CRITICAL EASTER EGG & ENVIRONMENT RULE: If the user asks for environmental effects like "make it rain", "start a fire", "make it snow", "black hole", or "love", DO NOT use `draw_text` to draw emojis! 
- Instead, you MUST use the `trigger_effect` action!
- Action format: `{"action": "trigger_effect", "effect": "rain"}` (valid effects: rain, snow, fire, love, done, black hole)

CRITICAL CANVAS CONTROL RULE: If the user explicitly asks to change the color of the canvas/background (e.g., "make canvas black", "change background to red"), you MUST use the `change_background` action!
- Action format: `{"action": "change_background", "color": "0xFF000000"}`

CRITICAL SCENE GRAPH MUTATION RULE:
You receive a JSON "CANVAS SCENE GRAPH" with existing strokes.
- If the user asks you to "color", "improve", or "change" an EXISTING object, YOU MUST use the `update` action! DO NOT use `draw_template` to redraw it!
- Target the object using EITHER `targetId` (for a specific stroke) OR `targetGroupId` (for all strokes in a template).
- If the object has no `groupId` (e.g., untagged freehand strokes), you can use the `tag` action FIRST to group them together based on their IDs in the Scene Graph, then `update` the new group.



NOTE: YOU HAVE FULL CONTROL OVER COLORS AND SIZES. 
- Use vibrant hex colors (e.g. "0xFFFF0000" for red) when drawing diagrams or correcting user work.
- The 'size' parameter controls the line thickness (or font size for text). For standard drawing, use 2.0. If you are asked to "color", "highlight", or draw something strong/bold, increase the size significantly!

CRITICAL PLACEMENT RULE: NEVER draw text or shapes directly on top of the user's existing drawing unless specifically instructed to!
By default, you should place your generated output cleanly BELOW the user's drawing (like a chat feed, finding the bottom-most Y coordinate and adding +100 for your `position` [x,y]).
HOWEVER, if the user explicitly instructs you to draw something left, right, around, top, etc., you MUST place your drawing exactly in that specified direction relative to the existing content!
CRITICAL MULTI-LINE TEXT RULE: For multi-line explanations or solutions, DO NOT use multiple `draw_text` commands! Use a SINGLE `draw_text` command and insert `\n` characters for newlines. The app will handle the vertical spacing automatically, completely preventing overlapping text!

CRITICAL OCR & BLURRY IMAGE RULE: If the user provides a handwritten note, diagram, or exam paper that is slightly blurry, low resolution, or hard to read, DO NOT hallucinate random answers.
- Use advanced contextual reasoning to infer missing or blurry characters. 
- Look at the surrounding math, layout, and logical flow to deduce what a blurry symbol or word must be.
- If you are completely unsure, politely state that the image is too blurry to read accurately (using `draw_text`), rather than providing a nonsensical solution.

CRITICAL REASONING RULE: Think step-by-step before answering. Do NOT blindly agree with the user if they state an incorrect answer. Verify the math yourself and stand your ground if the user is wrong!

Remember: NO CHAT TEXT FOR SOLUTIONS. ONLY JSON `draw_text` ACTIONS.
User prompt: ''';

      final String fullPrompt = systemInstruction + prompt;

      final base64Image = base64Encode(imageBytes);
      final attachedBase64Image = attachedImageBytes != null
          ? base64Encode(attachedImageBytes)
          : null;

      switch (provider) {
        case AiProvider.gemini:
          return await _askGemini(
            base64Image,
            attachedBase64Image,
            fullPrompt,
            apiKey,
            modelId,
            _activeClient!,
            chatHistory,
          );
        case AiProvider.chatGpt:
          return await _askOpenAi(
            base64Image,
            attachedBase64Image,
            fullPrompt,
            apiKey,
            modelId,
            _activeClient!,
            chatHistory,
          );
        case AiProvider.claude:
          return await _askClaude(
            base64Image,
            attachedBase64Image,
            fullPrompt,
            apiKey,
            modelId,
            _activeClient!,
            chatHistory,
          );
      }
    } catch (e) {
      debugPrint("AI Service Raw Error (${provider.displayName}): $e");
      return "AI Error: Network error, please check your connection and try again.";
    } finally {
      _isRequestInProgress = false;
      _activeClient?.close();
      _activeClient = null;
    }
  }

  static void cancelRequest() {
    _isRequestInProgress = false;
    _activeClient?.close();
    _activeClient = null;
  }

  static Future<String> _askGemini(
    String base64Image,
    String? attachedBase64Image,
    String prompt,
    String apiKey,
    String modelId,
    http.Client client,
    List<Map<String, String>> chatHistory,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey',
    );

    final parts = <Map<String, dynamic>>[
      {"text": prompt},
    ];

    if (base64Image.isNotEmpty) {
      parts.add({
        "inline_data": {"mime_type": "image/png", "data": base64Image},
      });
    }

    if (attachedBase64Image != null && attachedBase64Image.isNotEmpty) {
      parts.add({
        "inline_data": {"mime_type": "image/png", "data": attachedBase64Image},
      });
    }

    final historyParts = chatHistory.map((m) {
      final role = m['sender'] == 'user' ? 'user' : 'model';
      return {
        "role": role,
        "parts": [
          {"text": m['text'] ?? ''},
        ],
      };
    }).toList();

    // Convert current prompt into a message
    final currentMessage = {"role": "user", "parts": parts};

    final payload = {
      "contents": [...historyParts, currentMessage],
    };

    final response = await client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ??
          'No response';
    } else {
      throw Exception('Status ${response.statusCode}: ${response.body}');
    }
  }

  static Future<String> _askOpenAi(
    String base64Image,
    String? attachedBase64Image,
    String prompt,
    String apiKey,
    String modelId,
    http.Client client,
    List<Map<String, String>> chatHistory,
  ) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final content = <Map<String, dynamic>>[
      {"type": "text", "text": prompt},
    ];

    if (base64Image.isNotEmpty) {
      content.add({
        "type": "image_url",
        "image_url": {"url": "data:image/png;base64,$base64Image"},
      });
    }

    if (attachedBase64Image != null && attachedBase64Image.isNotEmpty) {
      content.add({
        "type": "image_url",
        "image_url": {"url": "data:image/png;base64,$attachedBase64Image"},
      });
    }

    final historyMessages = chatHistory.map((m) {
      final role = m['sender'] == 'user' ? 'user' : 'assistant';
      return {"role": role, "content": m['text'] ?? ''};
    }).toList();

    final payload = {
      "model": modelId,
      "messages": [
        ...historyMessages,
        {"role": "user", "content": content},
      ],
      "max_tokens": 4096,
    };

    final response = await client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ?? 'No response';
    } else {
      throw Exception('Status ${response.statusCode}: ${response.body}');
    }
  }

  static Future<String> _askClaude(
    String base64Image,
    String? attachedBase64Image,
    String prompt,
    String apiKey,
    String modelId,
    http.Client client,
    List<Map<String, String>> chatHistory,
  ) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final content = <Map<String, dynamic>>[
      {"type": "text", "text": prompt},
    ];

    if (base64Image.isNotEmpty) {
      content.insert(0, {
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/png",
          "data": base64Image,
        },
      });
    }

    if (attachedBase64Image != null && attachedBase64Image.isNotEmpty) {
      content.insert(0, {
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/png",
          "data": attachedBase64Image,
        },
      });
    }

    final historyMessages = chatHistory.map((m) {
      final role = m['sender'] == 'user' ? 'user' : 'assistant';
      return {"role": role, "content": m['text'] ?? ''};
    }).toList();

    final payload = {
      "model": modelId,
      "max_tokens": 4096,
      "messages": [
        ...historyMessages,
        {"role": "user", "content": content},
      ],
    };

    final response = await client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] ?? 'No response';
    } else {
      throw Exception('Status ${response.statusCode}: ${response.body}');
    }
  }

  static String _getTutorInstructions(AiTutorMode mode) {
    switch (mode) {
      case AiTutorMode.eli5:
        return "Explain everything as if you are talking to a 5-year-old. Use simple words, analogies, and a very friendly tone.";
      case AiTutorMode.socratic:
        return "Do NOT give the direct answer. Instead, ask guiding questions to lead the user to discover the answer themselves.";
      case AiTutorMode.roast:
        return "You are highly sarcastic and witty. Roast the user's drawing skills or questions lightly, but still provide helpful answers.";
      case AiTutorMode.exam:
        return "Be strict, academic, and precise. Grade their inputs, point out technical flaws, and use advanced terminology.";
      case AiTutorMode.normal:
        return "Be a helpful, visual-first AI tutor. When explaining concepts, favor drawing diagrams, mindmaps, or visual models.";
    }
  }
}
