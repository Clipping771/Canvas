import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<AiProvider, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var provider in AiProvider.values) {
      _controllers[provider] = TextEditingController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = ref.read(settingsProvider);
    for (var provider in AiProvider.values) {
      final key = state.apiKeys[provider];
      if (key != null) {
        _controllers[provider]!.text = key;
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    const Color headerColor = Color(0xFF8B9EB7);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF4A6078), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI settings',
          style: GoogleFonts.cormorantGaramond(
            color: const Color(0xFF1E293B),
            fontSize: 26,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          const Text(
            'PROVIDER',
            style: TextStyle(
              color: headerColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildActiveProviderCard(
            provider: AiProvider.gemini,
            title: 'Google Gemini',
            subtitle: 'gemini-2.5-pro',
            logoChar: 'G',
            state: state,
            isActive: state.selectedProvider == AiProvider.gemini,
          ),
          const SizedBox(height: 12),
          _buildInactiveProviderCard(
            provider: AiProvider.chatGpt,
            title: 'ChatGPT',
            subtitle: 'OpenAI · not connected',
            logoChar: 'GPT',
            state: state,
            isActive: state.selectedProvider == AiProvider.chatGpt,
          ),
          const SizedBox(height: 12),
          _buildInactiveProviderCard(
            provider: AiProvider.claude,
            title: 'Claude',
            subtitle: 'Anthropic · not connected',
            logoChar: 'C',
            state: state,
            isActive: state.selectedProvider == AiProvider.claude,
          ),
          const SizedBox(height: 32),
          const Text(
            'APP APPEARANCE',
            style: TextStyle(
              color: headerColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildAppearanceCard(state),
        ],
      ),
    );
  }

  Widget _buildActiveProviderCard({
    required AiProvider provider,
    required String title,
    required String subtitle,
    required String logoChar,
    required SettingsState state,
    required bool isActive,
  }) {
    if (!isActive) {
      return _buildInactiveProviderCard(
        provider: provider,
        title: title,
        subtitle: subtitle,
        logoChar: logoChar,
        state: state,
        isActive: isActive,
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    logoChar,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isActive && provider == AiProvider.gemini)
                        state.isFetchingModels 
                          ? const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: SizedBox(
                                height: 12, 
                                width: 12, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: state.availableModels.contains(state.selectedModel) 
                                    ? state.selectedModel 
                                    : (state.availableModels.isNotEmpty ? state.availableModels.first : 'gemini-2.5-pro'),
                                isDense: true,
                                iconSize: 16,
                                style: const TextStyle(
                                  color: Color(0xFF8B9EB7),
                                  fontSize: 13,
                                ),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    ref.read(settingsProvider.notifier).setModel(newValue);
                                  }
                                },
                                items: state.availableModels.map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            )
                      else
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF8B9EB7),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API key',
                  style: TextStyle(
                    color: Color(0xFF8B9EB7),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _controllers[provider],
                    obscureText: true,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      letterSpacing: 2.0,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 20),
                    ),
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).saveApiKey(provider, val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveProviderCard({
    required AiProvider provider,
    required String title,
    required String subtitle,
    required String logoChar,
    required SettingsState state,
    required bool isActive,
  }) {
    if (isActive) {
      return _buildActiveProviderCard(
        provider: provider,
        title: title,
        subtitle: subtitle,
        logoChar: logoChar,
        state: state,
        isActive: isActive,
      );
    }
    
    return GestureDetector(
      onTap: () {
        ref.read(settingsProvider.notifier).setProvider(provider);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                logoChar,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B9EB7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(SettingsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App font',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search and select any Google Font to use across the app.',
                  style: TextStyle(
                    color: Color(0xFF8B9EB7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.selectedFont,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Text(
                        'Aa',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Copy/paste shortcuts',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use Ctrl+C, Ctrl+V, and Ctrl+D on the canvas.',
                        style: TextStyle(
                          color: Color(0xFF8B9EB7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.enableKeyboardShortcuts,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setEnableKeyboardShortcuts(val);
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF3B82F6),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
