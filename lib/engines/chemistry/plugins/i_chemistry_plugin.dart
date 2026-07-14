/// Base interface for all chemistry domain plugins.
abstract class IChemistryPlugin {
  /// The unique identifier of the plugin.
  String get pluginId;

  /// The human-readable name of the plugin (e.g., "Organic Chemistry").
  String get name;

  /// Initializes the plugin (e.g., loading specific databases).
  Future<void> initialize();

  /// Analyzes a query or compound to see if this plugin can handle it.
  /// Returns a confidence score from 0.0 to 1.0.
  double canHandle(String query);

  /// Executes a domain-specific operation based on the query.
  Map<String, dynamic> execute(String query, Map<String, dynamic> context);
}
