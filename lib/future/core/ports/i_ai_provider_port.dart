/// Port interface for AI text generation providers.
///
/// ## Error Contract
/// Implementations must throw typed exceptions — never return error strings
/// as the result value. The following exception types are expected:
/// - [AiProviderException] — provider-level error (invalid API key, model not
///   found, content policy rejection, rate limit exceeded).
/// - [TimeoutException] — the provider did not respond within [timeout].
/// - [AiProviderQuotaException] — the account has exhausted its quota.
///
/// Callers must not interpret the return value as an error indicator. If the
/// call completes without throwing, the returned string is valid generated text.
///
/// ## Token and Cost Contract
/// - [maxTokens] caps the response length. Implementations must honour this
///   limit or throw [AiProviderException] if the provider does not support it.
/// - Implementations should log token usage via `dart:developer log()` at
///   level `INFO` for cost observability. The log entry should include prompt
///   token count, completion token count, and model name.
/// - Callers are responsible for validating prompt length before calling
///   [generateText]. Passing an unbounded prompt is a caller error.
///
/// ## Timeout Contract
/// If [timeout] is not specified, implementations must apply a reasonable
/// default (recommended: 30 seconds). Implementations must not block
/// indefinitely.
abstract class IAiProviderPort {
  /// Generates text from [prompt] using the configured AI provider.
  ///
  /// [maxTokens] limits the length of the generated response.
  /// [timeout] overrides the default request timeout.
  ///
  /// Returns the generated text on success. Never returns null or an
  /// empty string as a result — throws instead.
  ///
  /// Throws [AiProviderException] on provider-level failure.
  /// Throws [TimeoutException] if [timeout] is exceeded.
  Future<String> generateText(
    String prompt, {
    int? maxTokens,
    Duration timeout = const Duration(seconds: 30),
  });
}
