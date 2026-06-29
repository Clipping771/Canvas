enum AiProvider {
  gemini(
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta/models',
  ),
  chatGpt('ChatGPT (OpenAI)', 'https://api.openai.com/v1/models'),
  claude(
    'Claude (Anthropic)',
    'https://api.anthropic.com/v1/models',
  ); // Note: Anthropic doesn't have a standard models endpoint in the same way, but we'll mock it or handle it separately.

  final String displayName;
  final String modelsEndpoint;

  const AiProvider(this.displayName, this.modelsEndpoint);
}
