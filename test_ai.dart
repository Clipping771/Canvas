import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notesketch_pro/services/ai_agent_service.dart';

void main() async {
  try {
    print('Calling agent...');
    final response = await AiAgentService.askAgent(
      prompt: "draw a ball",
      provider: "google",
      apiKey: "fake_key", // It will use dotenv if not provided, or it might fail if key is empty
      modelId: "gemini-1.5-flash",
      chatHistory: [],
      canvasObjects: [],
    );
    print('Response: $response');
  } catch (e) {
    print('Error: $e');
  }
}
