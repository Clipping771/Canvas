import 'package:flutter/material.dart';
import '../../models/stroke.dart';
import '../../models/tool_type.dart';
import 'components/component_registry.dart';
import 'models/circuit_component.dart';
import 'models/circuit_pin.dart';
import 'models/logic_state.dart';
import 'models/signal_state.dart';
import 'core/simulation_tick.dart';
import 'components/battery.dart';
import 'components/ground.dart';
import 'components/switch_component.dart';
import 'components/led.dart';
import 'components/logic_gates.dart';
import 'components/clock.dart';
import 'components/resistor.dart';
import 'components/motor.dart';

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
    registry.register('clock', (s) => Clock(s));
    registry.register('oscillator', (s) => Clock(s));
    registry.register('resistor', (s) => Resistor(s));
    registry.register('motor', (s) => Motor(s));
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

    // Pass 2: Connect Pins via Wires
    for (var stroke in strokes) {
      if (stroke.toolType == ToolType.wire) {
        final sourceId = stroke.customMetadata?['sourceId'] as String?;
        final targetId = stroke.customMetadata?['targetId'] as String?;
        final sourcePinId = stroke.customMetadata?['sourcePinId'] as String?;
        final targetPinId = stroke.customMetadata?['targetPinId'] as String?;
        
        if (sourceId != null && targetId != null) {
          final sourceComp = _activeComponents[sourceId];
          final targetComp = _activeComponents[targetId];
          
          if (sourceComp != null && targetComp != null) {
            final sourcePin = sourcePinId != null 
                ? sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == sourcePinId, orElse: () => null)
                : sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
                
            final targetPin = targetPinId != null 
                ? targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == targetPinId, orElse: () => null)
                : targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.input, orElse: () => null);
            
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
          final sourcePinId = stroke.customMetadata?['sourcePinId'] as String?;
          final targetPinId = stroke.customMetadata?['targetPinId'] as String?;
          
          if (sourceId != null && targetId != null) {
            final sourceComp = _activeComponents[sourceId];
            final targetComp = _activeComponents[targetId];
            if (sourceComp != null && targetComp != null) {
              final sourcePin = sourcePinId != null 
                  ? sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == sourcePinId, orElse: () => null)
                  : sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
                  
              final targetPin = targetPinId != null 
                  ? targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == targetPinId, orElse: () => null)
                  : targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.input, orElse: () => null);
              if (sourcePin != null && targetPin != null) {
                targetPin.state = sourcePin.state.copyWith();
              }
            }
          }
        }
      }
    }

    // Pass 4: Visual Updates & Bezier Wire Generation
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
        final targetId = stroke.customMetadata?['targetId'] as String?;
        final sourcePinId = stroke.customMetadata?['sourcePinId'] as String?;
        final targetPinId = stroke.customMetadata?['targetPinId'] as String?;

        if (sourceId != null && targetId != null && _activeComponents.containsKey(sourceId) && _activeComponents.containsKey(targetId)) {
          final sourceComp = _activeComponents[sourceId]!;
          final targetComp = _activeComponents[targetId]!;

          final sourceStroke = strokes.firstWhere((s) => s.id == sourceId);
          final targetStroke = strokes.firstWhere((s) => s.id == targetId);

          final sourcePin = sourcePinId != null 
              ? sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == sourcePinId, orElse: () => null)
              : sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
              
          final targetPin = targetPinId != null 
              ? targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == targetPinId, orElse: () => null)
              : targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.input, orElse: () => null);

          if (sourcePin != null && targetPin != null) {
            final startPoint = sourceStroke.bounds.center + sourcePin.relativePosition;
            final endPoint = targetStroke.bounds.center + targetPin.relativePosition;
            
            final bezierPoints = _generateBezierPoints(startPoint, endPoint);
            
            final isPowered = sourcePin.state.logic == LogicState.high || sourcePin.state.voltage > 0;
            final targetColor = isPowered ? Colors.orange : Colors.grey;

            if (stroke.color != targetColor || stroke.points.length != bezierPoints.length || (stroke.points.isNotEmpty && stroke.points.first != bezierPoints.first)) {
              updatedStrokes.add(stroke.copyWith(
                color: targetColor,
                points: bezierPoints,
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

  List<Offset> _generateBezierPoints(Offset start, Offset end) {
    // Sagging bezier curve for wires
    final controlPoint1 = Offset(start.dx + (end.dx - start.dx) / 2, start.dy + 50);
    final controlPoint2 = Offset(end.dx - (end.dx - start.dx) / 2, end.dy + 50);
    
    final points = <Offset>[];
    for (double t = 0; t <= 1.0; t += 0.05) {
      final x = _cubicBezier(t, start.dx, controlPoint1.dx, controlPoint2.dx, end.dx);
      final y = _cubicBezier(t, start.dy, controlPoint1.dy, controlPoint2.dy, end.dy);
      points.add(Offset(x, y));
    }
    return points;
  }

  double _cubicBezier(double t, double p0, double p1, double p2, double p3) {
    final u = 1 - t;
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
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
