import 'package:vinci_board/engines/chemistry/plugins/i_chemistry_plugin.dart';

/// Manages all chemistry plugins and routes queries to the most appropriate one.
class ChemistryPluginManager {
  static final ChemistryPluginManager _instance =
      ChemistryPluginManager._internal();
  factory ChemistryPluginManager() => _instance;

  final List<IChemistryPlugin> _plugins = [];

  ChemistryPluginManager._internal();

  /// Registers a new plugin with the engine.
  void registerPlugin(IChemistryPlugin plugin) {
    _plugins.add(plugin);
    plugin.initialize();
  }

  /// Routes a query to the plugin with the highest confidence score.
  Map<String, dynamic> routeQuery(String query, Map<String, dynamic> context) {
    if (_plugins.isEmpty) return {"error": "No plugins registered"};

    IChemistryPlugin? bestPlugin;
    double maxConfidence = -1.0;

    for (var plugin in _plugins) {
      double confidence = plugin.canHandle(query);
      if (confidence > maxConfidence) {
        maxConfidence = confidence;
        bestPlugin = plugin;
      }
    }

    if (bestPlugin != null && maxConfidence > 0.0) {
      return bestPlugin.execute(query, context);
    }

    return {"error": "No suitable plugin found to handle query"};
  }
}
