import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_model_fetcher.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<AiProvider, TextEditingController> _controllers = {};
  final Map<AiProvider, List<String>> _fetchedModels = {};
  final Map<AiProvider, bool> _isFetching = {};

  @override
  void initState() {
    super.initState();
    for (var provider in AiProvider.values) {
      _controllers[provider] = TextEditingController();
      _isFetching[provider] = false;
      _fetchedModels[provider] = [];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill controllers from state
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

  Future<void> _fetchModels(AiProvider provider) async {
    final apiKey = _controllers[provider]!.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key first.')),
      );
      return;
    }

    setState(() => _isFetching[provider] = true);

    // Save the key first
    await ref.read(settingsProvider.notifier).saveApiKey(provider, apiKey);

    try {
      final models = await ApiModelFetcher.fetchModels(provider, apiKey);
      if (mounted) {
        setState(() {
          _fetchedModels[provider] = models;
          _isFetching[provider] = false;
        });

        // Auto-select the first model if the currently selected one isn't in the list
        final currentState = ref.read(settingsProvider);
        if (currentState.selectedProvider == provider &&
            !models.contains(currentState.selectedModel) &&
            models.isNotEmpty) {
          ref.read(settingsProvider.notifier).setModel(models.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching[provider] = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB), // Light Apple-like gray
      appBar: AppBar(
        title: const Text(
          'AI Settings',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Configure your Agentic AI providers below. Select the active provider using the radio buttons on the left.',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
          ...AiProvider.values
              .map((provider) => _buildProviderCard(provider, state)),
          const SizedBox(height: 32),
          const Text(
            'App Appearance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildResponseFormatSelector(state),
          const SizedBox(height: 24),
          _buildFontSelector(state),
          const SizedBox(height: 16),
          _buildArtStyleSelector(state),
        ],
      ),
    );
  }

  Widget _buildFontSelector(SettingsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Font',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search and select any Google Font to use across the app.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: state.selectedFont),
            optionsBuilder: (TextEditingValue textEditingValue) {
              final fonts = GoogleFonts.asMap().keys;
              if (textEditingValue.text.isEmpty) {
                return fonts.take(10);
              }
              return fonts
                  .where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  })
                  .take(50);
            },
            onSelected: (String selection) {
              ref.read(settingsProvider.notifier).setFont(selection);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search fonts (e.g. Roboto, Inter)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.font_download_outlined),
                    ),
                  );
                },
          ),
          const SizedBox(height: 24),
          const Text(
            'Keyboard Shortcuts',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable Copy/Paste Shortcuts'),
            subtitle: const Text('Use Ctrl+C, Ctrl+V, and Ctrl+D on the canvas'),
            value: state.enableKeyboardShortcuts,
            onChanged: (bool value) {
              ref.read(settingsProvider.notifier).setEnableKeyboardShortcuts(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildArtStyleSelector(SettingsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Drawing Style',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose how Vinci draws objects on your canvas.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<ArtStyleMode>(
                    title: const Text('Cute'),
                    value: ArtStyleMode.cute,
                    groupValue: state.artStyleMode,
                    onChanged: (ArtStyleMode? value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setArtStyleMode(value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<ArtStyleMode>(
                    title: const Text('Detailed'),
                    value: ArtStyleMode.detailed,
                    groupValue: state.artStyleMode,
                    onChanged: (ArtStyleMode? value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setArtStyleMode(value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<ArtStyleMode>(
                    title: const Text('Illustration'),
                    value: ArtStyleMode.illustration,
                    groupValue: state.artStyleMode,
                    onChanged: (ArtStyleMode? value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setArtStyleMode(value);
                      }
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

  Widget _buildResponseFormatSelector(SettingsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Response Format',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose how Vinci arranges objects on the canvas.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: state.responseFormat,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'Default', child: Text('Default (Smart Layout)')),
              DropdownMenuItem(value: 'Formatted', child: Text('Formatted (Grid/Structured)')),
              DropdownMenuItem(value: 'Random', child: Text('Random (Scattered)')),
            ],
            onChanged: (String? newValue) {
              if (newValue != null) {
                ref.read(settingsProvider.notifier).setResponseFormat(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(AiProvider provider, SettingsState state) {
    final isSelected = state.selectedProvider == provider;
    final hasModels = _fetchedModels[provider]!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          leading: Radio<AiProvider>(
          value: provider,
          groupValue: state.selectedProvider,
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setProvider(value);
            }
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          provider.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controllers[provider],
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'Enter your ${provider.displayName} API key',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  ref
                      .read(settingsProvider.notifier)
                      .saveApiKey(
                        provider,
                        _controllers[provider]!.text.trim(),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Key saved locally!')),
                  );
                },
              ),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFetching[provider]!
                  ? null
                  : () => _fetchModels(provider),
              icon: _isFetching[provider]!
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download),
              label: const Text(
                'Fetch Active Models',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (hasModels) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue:
                  state.selectedProvider == provider &&
                      _fetchedModels[provider]!.contains(state.selectedModel)
                  ? state.selectedModel
                  : _fetchedModels[provider]!.first,
              items: _fetchedModels[provider]!.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setModel(value);
                  ref.read(settingsProvider.notifier).setProvider(provider);
                }
              },
            ),
          ],
        ],
      ),
      ),
    );
  }
}
