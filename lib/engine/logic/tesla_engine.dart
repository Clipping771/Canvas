import 'package:flutter/material.dart';
import '../../models/stroke.dart';
import '../../models/tool_type.dart';
import 'components/component_registry.dart';
import 'models/circuit_component.dart';
import 'core/simulation_tick.dart';
import 'components/battery.dart';
import 'components/ground.dart';
import 'components/switch_component.dart';
import 'components/led.dart';
import 'components/logic_gates.dart';

class TeslaEngine {
  static final TeslaEngine _instance = TeslaEngine._internal();
  factory TeslaEngine() => _instance;
  TeslaEngine._internal() {
    _registerComponents();
  }

  final Map<String, CircuitComponent> _activeComponents = {};

  void _registerComponents() {
    final registry = ComponentRegistry();
    registry.register('battery', (s) => Battery(s));
    registry.register('vcc', (s) => Battery(s));
    registry.register('ground', (s) => Ground(s));
    registry.register('gnd', (s) => Ground(s));
    registry.register('switch', (s) => SwitchComponent(s));
    registry.register('light', (s) => LED(s));
    registry.register('led', (s) => LED(s));
    registry.register('and', (s) => AndGate(s));
    registry.register('or', (s) => OrGate(s));
    registry.register('not', (s) => NotGate(s));
  }

  static List<Stroke> updateWires(List<Stroke> strokes) {
    return _instance._runSimulationPass(strokes);
  }

  List<Stroke> _runSimulationPass(List<Stroke> strokes) {
    _activeComponents.clear();
    
    // Pass 1: Build graph nodes (Components)
    for (var stroke in strokes) {
      if (stroke.toolType == ToolType.text) {
        final component = ComponentRegistry().createComponent(stroke);
        if (component != null) {
          _activeComponents[stroke.id] = component;
        }
      }
    }

    // Pass 2: Connect Pins via Wires (To be fully implemented with pin-based hit testing)
    // For now, if a wire connects components, we assume it connects their first available input/output.
    // This will be replaced with precise sourcePinId / targetPinId logic.

    // Pass 3: Evaluate Components
    final tick = SimulationTick(tickCount: 0, deltaTimeSeconds: 0.16);
    for (var component in _activeComponents.values) {
      component.evaluate(tick);
    }

    // Pass 4: Visual Updates
    final List<Stroke> updatedStrokes = [];
    for (var stroke in strokes) {
      if (_activeComponents.containsKey(stroke.id)) {
        final comp = _activeComponents[stroke.id]!;
        final targetColor = comp.getActiveColor();
        if (stroke.color != targetColor) {
          updatedStrokes.add(stroke.copyWith(
            color: targetColor,
            version: stroke.version + 1,
          ));
          continue;
        }
      }
      updatedStrokes.add(stroke);
    }

    return updatedStrokes;
  }
}

extension StrokeCopyWith on Stroke {
  Stroke copyWith({
    String? id,
    String? groupId,
    String? name,
    List<Offset>? points,
    Color? color,
    double? size,
    double? rotation,
    ToolType? toolType,
    String? text,
    dynamic imageBytes,
    dynamic decodedImage,
    bool? isFilled,
    String? semanticMeaning,
    bool? physicsEnabled,
    Map<String, dynamic>? customMetadata,
    int? version,
  }) {
    return Stroke(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      toolType: toolType ?? this.toolType,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      decodedImage: decodedImage ?? this.decodedImage,
      isFilled: isFilled ?? this.isFilled,
      semanticMeaning: semanticMeaning ?? this.semanticMeaning,
      physicsEnabled: physicsEnabled ?? this.physicsEnabled,
      customMetadata: customMetadata ?? this.customMetadata,
      version: version ?? this.version,
    );
  }
}
