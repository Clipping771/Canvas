import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:notesketch_pro/services/ai_agent_service.dart';
import 'package:notesketch_pro/models/ai_provider.dart';

void main() {
  test('AiAgentService Rate Limit and Lock Test', () async {
    print('Starting rapid-fire rate-limit test...');
    
    // Simulate 5 rapid-fire calls
    final futures = <Future>[];
    for (int i = 1; i <= 5; i++) {
      print('Tap $i fired');
      futures.add(
        AiAgentService.askAgent(
          imageBytes: [],
          prompt: "test prompt $i",
          provider: AiProvider.gemini,
          apiKey: "fake_key",
          modelId: "gemini-1.5-flash",
          chatHistory: [],
          canvasObjects: [],
        ).then((res) => print('Tap $i Success: $res'))
         .catchError((e) => print('Tap $i Blocked: $e'))
      );
    }
    
    await Future.wait(futures);
    
    // Test the exact 1-second boundary
    print('Test complete. Lock should be released now.');
    
    // Wait for 0.9 seconds from the original request
    print('Waiting 0.9s (Boundary test)...');
    await Future.delayed(const Duration(milliseconds: 900));
    
    print('Trying Tap 6 at 0.9s (Should be blocked by 1-sec rate limit)...');
    try {
      final res = await AiAgentService.askAgent(
        imageBytes: [],
        prompt: "test prompt 6",
        provider: AiProvider.gemini,
        apiKey: "fake_key",
        modelId: "gemini-1.5-flash",
        chatHistory: [],
        canvasObjects: [],
      );
      print('Tap 6 Success: $res');
    } catch (e) {
      print('Tap 6 Blocked: $e');
    }

    // Wait an additional 0.2 seconds (total 1.1s since last successful request)
    print('Waiting an additional 0.2s (Total 1.1s elapsed)...');
    await Future.delayed(const Duration(milliseconds: 200));

    print('Trying Tap 7 at 1.1s (Should pass)...');
    try {
      final res = await AiAgentService.askAgent(
        imageBytes: [],
        prompt: "test prompt 7",
        provider: AiProvider.gemini,
        apiKey: "fake_key",
        modelId: "gemini-1.5-flash",
        chatHistory: [],
        canvasObjects: [],
      );
      print('Tap 7 Success: $res');
    } catch (e) {
      print('Tap 7 Blocked: $e');
    }
  });
}
