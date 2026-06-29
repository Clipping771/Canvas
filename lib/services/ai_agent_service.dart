import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/city_matcher.dart';
import '../models/ai_provider.dart';
import 'memory_service.dart';

class AiAgentService {
  /// Sends the canvas image to the AI agent and returns its response.
  static Future<String> askAgent({
    required List<int> imageBytes,
    required String prompt,
    required AiProvider provider,
    required String apiKey,
    required String modelId,
    required List<Map<String, String>> chatHistory,
    required List<Map<String, dynamic>> canvasObjects,
  }) async {
    if (apiKey.isEmpty) {
      return "Error: Please enter an API key for ${provider.displayName} in Settings first.";
    }

    final rulesList = await MemoryService.getRules();
    final memorySection = rulesList.isNotEmpty
        ? "\n\nCRITICAL MEMORY: You have learned the following rules from past mistakes. You MUST obey these rules:\n${rulesList.map((r) => "- $r").join("\n")}"
        : "";

    String historySection = "\n\n--- RECENT CHAT HISTORY (Context only) ---\n";
    for (var msg in chatHistory.take(5)) {
      historySection +=
          "${msg['sender']?.toUpperCase() ?? 'USER'}: ${msg['text']}\n";
    }
    historySection += "------------------------------------------\n";

    String liveContext = "";
    final fullContext =
        "${prompt.toLowerCase()} ${chatHistory.map((e) => e['text'] ?? '').join(" ").toLowerCase()}";
    if (fullContext.contains("temp") || fullContext.contains("weather")) {
      try {
        // Try regex first
        final regex = RegExp(
          r'(?:in|for|at|of)\s+([a-zA-Z]+)',
          caseSensitive: false,
        );
        final match = regex.firstMatch(fullContext);
        String? detectedCity;

        if (match != null) {
          detectedCity = CityMatcher.findBestMatch(match.group(1)!);
        }

        // If regex fails, fallback to token fuzzy matching
        if (detectedCity == null) {
          final words = fullContext.split(RegExp(r'\W+'));
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
        '''You are an agentic AI assistant inside a drawing app.
You have the ability to draw and write directly on the user's canvas.
$memorySection$liveContext$objectsContext

CRITICAL INSTRUCTION: Your output MUST ALWAYS be a single JSON object in this exact format:
```json
{
  "rationale": "Explain your design reasoning here. Do NOT make claims about what you drew, updated, or removed (e.g. NEVER say 'I added a tree'). Just explain WHY you chose a color or style.",
  "ops": [
    // Array of action objects
  ]
}
```
If you don't need to do any actions, just return an empty "ops" array. If the user asks a conversational question or you want to reply with text, YOU MUST use the "draw_text" action to write your response directly onto the canvas! Do NOT just put it in the rationale, and NEVER output raw conversational text outside the JSON. YOUR ENTIRE RESPONSE MUST BE VALID PARSABLE JSON.

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
11. {"action": "tween_area", "rect": [x, y, w, h], "dx": 20, "dy": 0, "scale": 1.0, "rotation": 0.0, "duration_ms": 2000}
12. {"action": "learn_rule", "rule": "Never draw over the image"}
13. {"action": "insert_widget", "type": "weather", "city": "London", "position": [x, y]}
14. {"action": "draw_template", "name": "frog", "position": [x, y], "size": 100, "isFilled": false} (Available names: frog, car, house, tree. Do NOT invent new names!)
15. {"action": "draw_svg", "path": "M 10 10 C 20 20, 40 20, 50 10 Z", "position": [x, y], "scale": 1.0, "color": "0xFF00FF00"} (Use this for drawing DETAILED arbitrary custom shapes like snakes, carts, cats, etc! Output a single valid SVG path data string.)
16. {"action": "update", "targetId": "s_123", "targetGroupId": "tree", "patch": {"color": "0xFF00FF00", "isFilled": true}}
17. {"action": "remove", "targetId": "s_123", "targetGroupId": "tree"}
18. {"action": "tag", "ids": ["s_1", "s_2"], "name": "house"}
19. {"action": "apply_gravity"}

CRITICAL UML AND CHARTS RULE: If the user asks for a CHART, GRAPH, WIREFRAME, or MINDMAP, use the `insert_uml` action with valid PlantUML code.
- Do NOT use `@startsalt` for tables! It looks like a terrible 1990s wireframe and the user hates it!

CRITICAL TABLE AND LIST RULE: When the user asks for a TABLE or LIST (like app features, pricing, or schedules), DO NOT draw boxes or rectangles! 
- Just use `draw_text` to write the list directly on the canvas in a clean, readable format.
- Do NOT use `draw_rect` or background cards as they take too long to draw and don't look good for simple lists.

CRITICAL MEMORY & SELF-CORRECTION RULE: If the user corrects a mistake you made, you MUST use the `learn_rule` action!

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

CRITICAL INTENTION & PHYSICS INSTRUCTION: You must smartly interpret the user's physical or magical intentions and translate them into `tween_area` parameters! 
- "Anti-gravity" / "Float" / "Fly" -> large negative `dy` (e.g. -600)
- "Wind" / "Blow away" -> large `dx` (e.g. 800)
- "Spin" / "Rotate" -> adjust `rotation` (e.g. 3.14 for 180 deg)
- "Shrink" / "Vanish" -> `scale`: 0.1
- "Grow" / "Expand" -> `scale`: 3.0
- "Gravity" / "Fall" -> YOU MUST use the `apply_gravity` action! Do NOT use `tween_area` for gravity! Do NOT use `draw_text` for gravity!
Use your intelligence to combine these (e.g. floating away while spinning) and set appropriate `duration_ms` (1000-3000ms).
CRITICAL WARNING: DO NOT BLINDLY COPY THE EXAMPLE JSON! You MUST estimate the actual pixel coordinates [x, y, w, h] of the objects you see in the provided image based on the canvas size!
You can output MULTIPLE tween_area commands in your JSON array to move different objects simultaneously!
Example of making two separate circles collide over 2 seconds:
[
  {"action": "tween_area", "rect": [50, 100, 40, 40], "dx": 200, "dy": 0, "duration_ms": 2000},
  {"action": "tween_area", "rect": [400, 100, 40, 40], "dx": -200, "dy": 0, "duration_ms": 2000}
]

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

    try {
      final base64Image = base64Encode(imageBytes);

      switch (provider) {
        case AiProvider.gemini:
          return await _askGemini(base64Image, fullPrompt, apiKey, modelId);
        case AiProvider.chatGpt:
          return await _askOpenAi(base64Image, fullPrompt, apiKey, modelId);
        case AiProvider.claude:
          return await _askClaude(base64Image, fullPrompt, apiKey, modelId);
      }
    } catch (e) {
      return "AI Error (${provider.displayName}): $e";
    }
  }

  static Future<String> _askGemini(
    String base64Image,
    String prompt,
    String apiKey,
    String modelId,
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

    final payload = {
      "contents": [
        {"parts": parts},
      ],
    };

    final response = await http
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
    String prompt,
    String apiKey,
    String modelId,
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

    final payload = {
      "model": modelId,
      "messages": [
        {"role": "user", "content": content},
      ],
      "max_tokens": 1000,
    };

    final response = await http
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
    String prompt,
    String apiKey,
    String modelId,
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

    final payload = {
      "model": modelId,
      "max_tokens": 1024,
      "messages": [
        {"role": "user", "content": content},
      ],
    };

    final response = await http
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
}
