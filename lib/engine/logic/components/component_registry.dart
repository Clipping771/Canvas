import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import 'generic_component.dart';
import 'dart:convert';

typedef ComponentFactory = CircuitComponent Function(Stroke stroke);

class ComponentRegistry {
  static final ComponentRegistry _instance = ComponentRegistry._internal();
  factory ComponentRegistry() => _instance;
  ComponentRegistry._internal();

  final Map<String, ComponentFactory> _factories = {};

  void register(String keyword, ComponentFactory factory) {
    _factories[keyword.toLowerCase()] = factory;
  }

  void registerFromJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final definition = ComponentDefinition.fromJson(data);
      final factory = (Stroke stroke) => GenericComponent(stroke, definition);
      
      // Register all aliases
      for (var alias in definition.aliases) {
        register(alias, factory);
      }
      // Register main name
      register(definition.name, factory);
    } catch (e) {
      print('Failed to register plugin from JSON: $e');
    }
  }

  CircuitComponent? createComponent(Stroke stroke) {
    if (stroke.text == null) return null;
    final text = stroke.text!.toLowerCase();
    
    // Check for exact word matches to avoid "resistor" triggering "or"
    final words = text.split(RegExp(r'\s+'));
    for (var entry in _factories.entries) {
      if (words.contains(entry.key) || text.startsWith(entry.key + ' ')) {
        return entry.value(stroke);
      }
    }
    return null;
  }
}
