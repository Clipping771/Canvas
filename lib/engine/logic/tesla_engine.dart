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

    // Pass 2: Connect Pins via Wires (Fallback to first available input/output if pin ID is missing)
    for (var stroke in strokes) {
      if (stroke.toolType == ToolType.wire) {
        final sourceId = stroke.customMetadata?['sourceId'] as String?;
        final targetId = stroke.customMetadata?['targetId'] as String?;
        
        if (sourceId != null && targetId != null) {
          final sourceComp = _activeComponents[sourceId];
          final targetComp = _activeComponents[targetId];
          
          if (sourceComp != null && targetComp != null) {
            // Find first output pin of source and first input pin of target
            final sourcePin = sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
            final targetPin = targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.input, orElse: () => null);
            
            if (sourcePin != null && targetPin != null) {
              targetPin.state = sourcePin.state.copyWith();
            }
          }
        }
      }
    }

    // Pass 3: Evaluate Components (Multiple passes to ensure propagation)
    final tick = SimulationTick(tickCount: 0, deltaTimeSeconds: 0.16);
    for (int i = 0; i < 3; i++) {
      for (var component in _activeComponents.values) {
        component.evaluate(tick);
      }
      
      // Re-propagate wires after evaluation
      for (var stroke in strokes) {
        if (stroke.toolType == ToolType.wire) {
          final sourceId = stroke.customMetadata?['sourceId'] as String?;
          final targetId = stroke.customMetadata?['targetId'] as String?;
          if (sourceId != null && targetId != null) {
            final sourceComp = _activeComponents[sourceId];
            final targetComp = _activeComponents[targetId];
            if (sourceComp != null && targetComp != null) {
              final sourcePin = sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
              final targetPin = targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.input, orElse: () => null);
              if (sourcePin != null && targetPin != null) {
                targetPin.state = sourcePin.state.copyWith();
              }
            }
          }
        }
      }
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
      } else if (stroke.toolType == ToolType.wire) {
        final sourceId = stroke.customMetadata?['sourceId'] as String?;
        if (sourceId != null && _activeComponents.containsKey(sourceId)) {
          final sourceComp = _activeComponents[sourceId]!;
          final sourcePin = sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
          if (sourcePin != null && (sourcePin.state.logic == LogicState.high || sourcePin.state.voltage > 0)) {
            if (stroke.color != Colors.orange) {
              updatedStrokes.add(stroke.copyWith(
                color: Colors.orange,
                version: stroke.version + 1,
              ));
              continue;
            }
          } else {
             if (stroke.color != Colors.grey) {
              updatedStrokes.add(stroke.copyWith(
                color: Colors.grey,
                version: stroke.version + 1,
              ));
              continue;
            }
          }
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
