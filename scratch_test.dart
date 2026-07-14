import 'package:flutter/foundation.dart';
import 'dart:async';

class AiAgentService {
  static bool _isRequestInProgress = false;
  static DateTime? _lastRequestTime;

  static Future<String> askAgent(String prompt, int i) async {
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

    try {
      await Future.delayed(Duration(milliseconds: 500));
      return 'Response to $prompt';
    } finally {
      _isRequestInProgress = false;
    }
  }
}

void main() async {
  debugPrint('Starting rapid-fire rate-limit test...');

  final futures = <Future>[];
  for (int i = 1; i <= 5; i++) {
    debugPrint('Tap $i fired');
    futures.add(
      AiAgentService.askAgent("test prompt $i", i)
          .then((res) => debugPrint('Tap $i Success: $res'))
          .catchError((e) => debugPrint('Tap $i Blocked: $e')),
    );
  }

  await Future.wait(futures);
  debugPrint('Test complete. Releasing lock and waiting 1.5 seconds...');

  await Future.delayed(Duration(milliseconds: 1500));

  debugPrint('Trying Tap 6 after lock release...');
  try {
    final res = await AiAgentService.askAgent("test prompt 6", 6);
    debugPrint('Tap 6 Success: $res');
  } catch (e) {
    debugPrint('Tap 6 Blocked: $e');
  }
}
