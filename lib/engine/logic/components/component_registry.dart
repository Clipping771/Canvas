import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';

typedef ComponentFactory = CircuitComponent Function(Stroke stroke);

class ComponentRegistry {
  static final ComponentRegistry _instance = ComponentRegistry._internal();
  factory ComponentRegistry() => _instance;
  ComponentRegistry._internal();

  final Map<String, ComponentFactory> _factories = {};

  void register(String keyword, ComponentFactory factory) {
    _factories[keyword.toLowerCase()] = factory;
  }

  CircuitComponent? createComponent(Stroke stroke) {
    if (stroke.text == null) return null;
    final text = stroke.text!.toLowerCase();
    
    // Check for exact matches or containing matches
    for (var entry in _factories.entries) {
      if (text.contains(entry.key)) {
        return entry.value(stroke);
      }
    }
    return null;
  }
}
