import 'package:notesketch_pro/services/ai_agent_service.dart';
import 'package:notesketch_pro/services/ai_agent_service.dart';
import 'package:notesketch_pro/models/ai_provider.dart';

void main() async {
  try {
    print('Calling agent...');
    final response = await AiAgentService.askAgent(
      imageBytes: [],
      prompt: "draw a ball",
      provider: AiProvider.gemini,
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
