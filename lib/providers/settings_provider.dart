import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_provider.dart';

enum AiResponseFormat { auto, conversational, diagram, code }

class SettingsState {
  final Map<AiProvider, String> apiKeys;
  final AiProvider selectedProvider;
  final String selectedModel;
  final String selectedFont;
  final String responseFormat;
  final bool enableKeyboardShortcuts;

  SettingsState({
    this.apiKeys = const {},
    this.selectedProvider = AiProvider.gemini,
    this.selectedModel = 'gemini-2.5-pro',
    this.selectedFont = 'Inter',
    this.responseFormat = 'Default',
    this.enableKeyboardShortcuts = true,
  });

  SettingsState copyWith({
    Map<AiProvider, String>? apiKeys,
    AiProvider? selectedProvider,
    String? selectedModel,
    String? selectedFont,
    String? responseFormat,
    bool? enableKeyboardShortcuts,
  }) {
    return SettingsState(
      apiKeys: apiKeys ?? this.apiKeys,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedFont: selectedFont ?? this.selectedFont,
      responseFormat: responseFormat ?? this.responseFormat,
      enableKeyboardShortcuts: enableKeyboardShortcuts ?? this.enableKeyboardShortcuts,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    final Map<AiProvider, String> keys = {};
    for (var provider in AiProvider.values) {
      final key = _prefs.getString('api_key_${provider.name}');
      if (key != null && key.isNotEmpty) {
        keys[provider] = key;
      }
    }

    final savedProviderName =
        _prefs.getString('selected_provider') ?? AiProvider.gemini.name;
    final savedProvider = AiProvider.values.firstWhere(
      (p) => p.name == savedProviderName,
      orElse: () => AiProvider.gemini,
    );

    final savedModel = _prefs.getString('selected_model') ?? 'gemini-2.5-pro';
    final savedFont = _prefs.getString('selected_font') ?? 'Inter';
    final savedResponseFormat = _prefs.getString('response_format') ?? 'Default';
    final savedShortcuts = _prefs.getBool('enable_shortcuts') ?? true;

    state = state.copyWith(
      apiKeys: keys,
      selectedProvider: savedProvider,
      selectedModel: savedModel,
      selectedFont: savedFont,
      responseFormat: savedResponseFormat,
      enableKeyboardShortcuts: savedShortcuts,
    );
  }

  Future<void> saveApiKey(AiProvider provider, String key) async {
    await _prefs.setString('api_key_${provider.name}', key);

    final newKeys = Map<AiProvider, String>.from(state.apiKeys);
    if (key.isEmpty) {
      newKeys.remove(provider);
    } else {
      newKeys[provider] = key;
    }

    state = state.copyWith(apiKeys: newKeys);
  }

  Future<void> setProvider(AiProvider provider) async {
    await _prefs.setString('selected_provider', provider.name);
    state = state.copyWith(selectedProvider: provider);
  }

  Future<void> setModel(String modelId) async {
    await _prefs.setString('selected_model', modelId);
    state = state.copyWith(selectedModel: modelId);
  }

  Future<void> setFont(String fontName) async {
    await _prefs.setString('selected_font', fontName);
    state = state.copyWith(selectedFont: fontName);
  }

  Future<void> setResponseFormat(String format) async {
    await _prefs.setString('response_format', format);
    state = state.copyWith(responseFormat: format);
  }

  Future<void> setEnableKeyboardShortcuts(bool enable) async {
    await _prefs.setBool('enable_shortcuts', enable);
    state = state.copyWith(enableKeyboardShortcuts: enable);
  }

  String? getApiKey(AiProvider provider) {
    return state.apiKeys[provider];
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
