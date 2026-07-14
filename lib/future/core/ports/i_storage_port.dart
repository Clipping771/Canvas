/// Port interface for key-value structured data persistence.
///
/// ## Schema Version Contract
/// Every [save] call must include a [schemaVersion]. When [load] returns data,
/// callers must check the `'_schemaVersion'` key in the returned map and apply
/// any necessary migrations before consuming other fields.
///
/// Implementations must store the [schemaVersion] as `'_schemaVersion'` inside
/// the persisted data map so it round-trips through serialisation.
///
/// ## Error Contract
/// - [save] throws [StorageException] on write failure (disk full, permission denied).
/// - [load] returns null when the key does not exist. Never throws on a missing key.
/// - [load] throws [StorageException] on read failure or data corruption.
/// - [delete] is idempotent — does not throw when the key does not exist.
///
/// ## Key Convention
/// Keys must be non-empty strings. Keys prefixed with `_` are reserved for
/// internal metadata (e.g., `'_schemaVersion'`). Callers must not use
/// underscore-prefixed keys for application data.
abstract class IStoragePort {
  /// Persists [data] under [key] at the given [schemaVersion].
  ///
  /// [schemaVersion] defaults to 1. Increment it whenever the shape of [data]
  /// changes in a way that is not backward-compatible.
  ///
  /// Throws [StorageException] on write failure.
  Future<void> save(
    String key,
    Map<String, dynamic> data, {
    int schemaVersion = 1,
  });

  /// Loads the data stored under [key].
  ///
  /// Returns null if the key does not exist.
  /// The returned map includes `'_schemaVersion'` — callers must check this
  /// value and migrate the data if it does not match the expected version.
  /// Throws [StorageException] on read failure or corruption.
  Future<Map<String, dynamic>?> load(String key);

  /// Removes the entry for [key]. Idempotent — safe to call when key does
  /// not exist.
  Future<void> delete(String key);
}
