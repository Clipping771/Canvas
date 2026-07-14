import 'package:flutter/foundation.dart';
import 'package:vinci_board/adapters/ai/ai_agent_service.dart';
import 'package:vinci_board/core/models/ai_provider.dart';

void main() async {
  try {
    debugPrint('Calling agent...');
    final response = await AiAgentService.askAgent(
      imageBytes: [],
      prompt: "draw a ball",
      provider: AiProvider.gemini,
      apiKey:
          "fake_key", // It will use dotenv if not provided, or it might fail if key is empty
      modelId: "gemini-1.5-flash",
      chatHistory: [],
      canvasObjects: [],
    );
    debugPrint('Response: $response');
  } catch (e) {
    debugPrint('Error: $e');
  }
}
