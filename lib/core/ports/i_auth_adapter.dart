/// Port interface for SSO authentication providers.
///
/// Implementations must conform to the following error contract:
/// - [loginWithSSO] throws [AuthException] on failure (invalid domain,
///   network error, provider rejection). Never returns null or an empty string.
/// - [logout] is idempotent. Calling it when no session is active must not throw.
/// - [getCurrentUser] returns null when no session is active, never throws.
///
/// The [loginWithSSO] return value is a **session token** — an opaque string
/// identifying the authenticated session. It must not be logged or persisted
/// in plaintext. Pass it to subsequent authenticated API calls as a bearer token.
///
/// [getCurrentUser] returns a map with at minimum the following keys:
/// ```
///   'id'       : String — unique user identifier
///   'name'     : String — display name
///   'email'    : String — institutional email address
///   'role'     : String — one of: 'SchoolAdmin', 'Teacher', 'Student'
///   'schoolId' : String — the user's institution identifier
/// ```
/// Callers must not assume additional keys are present without checking.
abstract class IAuthAdapter {
  String get providerName;

  /// Authenticates the user against the SSO provider for [domain].
  ///
  /// Returns a session token on success.
  /// Throws [AuthException] on authentication failure.
  /// Throws [TimeoutException] if the provider does not respond within
  /// the implementation's configured timeout.
  Future<String> loginWithSSO(String domain);

  /// Terminates the current session. Idempotent — safe to call when not
  /// authenticated.
  Future<void> logout();

  /// Returns the currently authenticated user's profile, or null if no
  /// session is active. Never throws.
  Future<Map<String, dynamic>?> getCurrentUser();
}
