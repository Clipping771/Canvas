import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_provider.dart';

enum ArtStyleMode { cute, detailed, illustration }

class SettingsState {
  final Map<AiProvider, String> apiKeys;
  final AiProvider selectedProvider;
  final String selectedModel;
  final String selectedFont;
  final ArtStyleMode artStyleMode;
  final String responseFormat;

  SettingsState({
    this.apiKeys = const {},
    this.selectedProvider = AiProvider.gemini,
    this.selectedModel = 'gemini-2.5-pro',
    this.selectedFont = 'Inter',
    this.artStyleMode = ArtStyleMode.detailed,
    this.responseFormat = 'Default',
  });

  SettingsState copyWith({
    Map<AiProvider, String>? apiKeys,
    AiProvider? selectedProvider,
    String? selectedModel,
    String? selectedFont,
    ArtStyleMode? artStyleMode,
    String? responseFormat,
  }) {
    return SettingsState(
      apiKeys: apiKeys ?? this.apiKeys,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedFont: selectedFont ?? this.selectedFont,
      artStyleMode: artStyleMode ?? this.artStyleMode,
      responseFormat: responseFormat ?? this.responseFormat,
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
    final savedArtStyle = _prefs.getString('art_style_mode') ?? 'cute';
    final artStyleMode = savedArtStyle == 'detailed'
        ? ArtStyleMode.detailed
        : savedArtStyle == 'illustration'
            ? ArtStyleMode.illustration
            : ArtStyleMode.cute;
    final savedResponseFormat = _prefs.getString('response_format') ?? 'Default';

    state = state.copyWith(
      apiKeys: keys,
      selectedProvider: savedProvider,
      selectedModel: savedModel,
      selectedFont: savedFont,
      artStyleMode: artStyleMode,
      responseFormat: savedResponseFormat,
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

  Future<void> setArtStyleMode(ArtStyleMode mode) async {
    await _prefs.setString('art_style_mode', mode.name);
    state = state.copyWith(artStyleMode: mode);
  }

  Future<void> setResponseFormat(String format) async {
    await _prefs.setString('response_format', format);
    state = state.copyWith(responseFormat: format);
  }

  String? getApiKey(AiProvider provider) {
    return state.apiKeys[provider];
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
