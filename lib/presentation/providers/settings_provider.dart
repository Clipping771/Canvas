import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinci_board/core/models/ai_provider.dart';

enum AiResponseFormat { auto, conversational, diagram, code }

class SettingsState {
  final Map<AiProvider, String> apiKeys;
  final AiProvider selectedProvider;
  final String selectedModel;
  final String selectedFont;
  final double selectedFontSize;
  final String responseFormat;
  final bool enableKeyboardShortcuts;
  final List<String> availableModels;
  final bool isFetchingModels;

  SettingsState({
    this.apiKeys = const {},
    this.selectedProvider = AiProvider.gemini,
    this.selectedModel = 'gemini-2.5-pro',
    this.selectedFont = 'Inter',
    this.selectedFontSize = 18.0,
    this.responseFormat = 'Default',
    this.enableKeyboardShortcuts = true,
    this.availableModels = const [
      'gemini-2.5-pro',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ],
    this.isFetchingModels = false,
  });

  SettingsState copyWith({
    Map<AiProvider, String>? apiKeys,
    AiProvider? selectedProvider,
    String? selectedModel,
    String? selectedFont,
    double? selectedFontSize,
    String? responseFormat,
    bool? enableKeyboardShortcuts,
    List<String>? availableModels,
    bool? isFetchingModels,
  }) {
    return SettingsState(
      apiKeys: apiKeys ?? this.apiKeys,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedFont: selectedFont ?? this.selectedFont,
      selectedFontSize: selectedFontSize ?? this.selectedFontSize,
      responseFormat: responseFormat ?? this.responseFormat,
      enableKeyboardShortcuts:
          enableKeyboardShortcuts ?? this.enableKeyboardShortcuts,
      availableModels: availableModels ?? this.availableModels,
      isFetchingModels: isFetchingModels ?? this.isFetchingModels,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  SharedPreferences? _prefs;

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _loadSettings() async {
    final prefs = await _getPrefs();

    final Map<AiProvider, String> keys = {};
    for (var provider in AiProvider.values) {
      final key = prefs.getString('api_key_${provider.name}');
      if (key != null && key.isNotEmpty) {
        keys[provider] = key;
      }
    }

    final savedProviderName =
        prefs.getString('selected_provider') ?? AiProvider.gemini.name;
    final savedProvider = AiProvider.values.firstWhere(
      (p) => p.name == savedProviderName,
      orElse: () => AiProvider.gemini,
    );

    final savedModel = prefs.getString('selected_model') ?? 'gemini-2.5-pro';
    final savedFont = prefs.getString('selected_font') ?? 'Inter';
    final savedFontSize = prefs.getDouble('selected_font_size') ?? 18.0;
    final savedResponseFormat = prefs.getString('response_format') ?? 'Default';
    final savedShortcuts = prefs.getBool('enable_shortcuts') ?? true;

    state = state.copyWith(
      apiKeys: keys,
      selectedProvider: savedProvider,
      selectedModel: savedModel,
      selectedFont: savedFont,
      selectedFontSize: savedFontSize,
      responseFormat: savedResponseFormat,
      enableKeyboardShortcuts: savedShortcuts,
    );

    // Fetch models if we have an API key for the selected provider
    if (keys[savedProvider] != null) {
      _fetchModels(savedProvider, keys[savedProvider]!);
    }
  }

  Future<void> saveApiKey(AiProvider provider, String key) async {
    final prefs = await _getPrefs();
    await prefs.setString('api_key_${provider.name}', key);

    final newKeys = Map<AiProvider, String>.from(state.apiKeys);
    if (key.isEmpty) {
      newKeys.remove(provider);
    } else {
      newKeys[provider] = key;
    }

    state = state.copyWith(apiKeys: newKeys);

    // If we just saved a key for the current provider, fetch models
    if (provider == state.selectedProvider && key.isNotEmpty) {
      await _fetchModels(provider, key);
    }
  }

  Future<void> _fetchModels(AiProvider provider, String apiKey) async {
    if (provider != AiProvider.gemini) return;

    state = state.copyWith(isFetchingModels: true);
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map((m) => m['name'] as String)
            .where((name) => name.contains('gemini'))
            .map((name) => name.replaceAll('models/', ''))
            .toList();

        if (models.isNotEmpty) {
          state = state.copyWith(
            availableModels: models,
            isFetchingModels: false,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
    }

    // Fallback if fetch fails
    state = state.copyWith(
      isFetchingModels: false,
      availableModels: ['gemini-2.5-pro', 'gemini-1.5-flash', 'gemini-1.5-pro'],
    );
  }

  Future<void> setProvider(AiProvider provider) async {
    final prefs = await _getPrefs();
    await prefs.setString('selected_provider', provider.name);
    state = state.copyWith(selectedProvider: provider);

    // Fetch models if switching to gemini and we have a key
    if (provider == AiProvider.gemini && state.apiKeys[provider] != null) {
      await _fetchModels(provider, state.apiKeys[provider]!);
    }
  }

  Future<void> setModel(String modelId) async {
    final prefs = await _getPrefs();
    await prefs.setString('selected_model', modelId);
    state = state.copyWith(selectedModel: modelId);
  }

  Future<void> setFont(String fontName) async {
    final prefs = await _getPrefs();
    await prefs.setString('selected_font', fontName);
    state = state.copyWith(selectedFont: fontName);
  }

  Future<void> setFontSize(double size) async {
    final prefs = await _getPrefs();
    await prefs.setDouble('selected_font_size', size);
    state = state.copyWith(selectedFontSize: size);
  }

  Future<void> setResponseFormat(String format) async {
    final prefs = await _getPrefs();
    await prefs.setString('response_format', format);
    state = state.copyWith(responseFormat: format);
  }

  Future<void> setEnableKeyboardShortcuts(bool enable) async {
    final prefs = await _getPrefs();
    await prefs.setBool('enable_shortcuts', enable);
    state = state.copyWith(enableKeyboardShortcuts: enable);
  }

  String? getApiKey(AiProvider provider) {
    return state.apiKeys[provider];
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
