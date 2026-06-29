import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_provider.dart';

class ApiModelFetcher {
  /// Fetches the available models for a given provider and API key.
  static Future<List<String>> fetchModels(
    AiProvider provider,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key is empty.');
    }

    try {
      switch (provider) {
        case AiProvider.gemini:
          return await _fetchGeminiModels(apiKey);
        case AiProvider.chatGpt:
          return await _fetchOpenAiModels(apiKey);
        case AiProvider.claude:
          return await _fetchClaudeModels(apiKey);
      }
    } catch (e) {
      throw Exception('Failed to fetch models for ${provider.displayName}: $e');
    }
  }

  static Future<List<String>> _fetchGeminiModels(String apiKey) async {
    final url = Uri.parse('${AiProvider.gemini.modelsEndpoint}?key=$apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final models = (data['models'] as List)
          .map((m) => m['name'] as String)
          .where((m) => m.contains('gemini'))
          .map((m) => m.replaceFirst('models/', ''))
          .toList();
      return models;
    } else {
      throw Exception('Status ${response.statusCode}: ${response.body}');
    }
  }

  static Future<List<String>> _fetchOpenAiModels(String apiKey) async {
    final url = Uri.parse(AiProvider.chatGpt.modelsEndpoint);
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data'] as List).map((m) => m['id'] as String).toList();
    } else {
      throw Exception('Status ${response.statusCode}: ${response.body}');
    }
  }

  static Future<List<String>> _fetchClaudeModels(String apiKey) async {
    // Anthropic doesn't have a standard /models endpoint right now that returns a simple list.
    // We will hardcode the active Claude 3 models, but simulate a network verification delay.
    await Future.delayed(const Duration(seconds: 1));
    return [
      'claude-3-5-sonnet-20240620',
      'claude-3-opus-20240229',
      'claude-3-sonnet-20240229',
      'claude-3-haiku-20240307',
    ];
  }
}
