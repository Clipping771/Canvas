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
import 'components/capacitor.dart';
import 'components/inductor.dart';
import 'components/oscilloscope.dart';
import 'components/scriptable_chip.dart';
import 'components/sub_circuit.dart';
import 'components/motor.dart';
import 'components/portal.dart';
import 'core/circuit_node.dart';
import 'core/mna_solver.dart';

class TeslaEngine {
  static final TeslaEngine _instance = TeslaEngine._internal();
  factory TeslaEngine() => _instance;
  TeslaEngine._internal() {
    _registerComponents();
  }

  final Map<String, CircuitComponent> _activeComponents = {};
  Map<String, CircuitComponent> get activeComponents => _activeComponents;
  List<CircuitNode> _latestNodes = [];

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
    registry.register('capacitor', (s) => Capacitor(s));
    registry.register('inductor', (s) => Inductor(s));
    registry.register('oscilloscope', (s) => Oscilloscope(s));
    registry.register('mcu', (s) => ScriptableChip(s));
    registry.register('chip', (s) => ScriptableChip(s));
    registry.register('ic', (s) => SubCircuitComponent(s));
    registry.register('motor', (s) => Motor(s));
  }

  static List<Stroke> updateWires(List<Stroke> strokes) {
    return _instance._runSimulationPass(strokes);
  }

  // --- SPICE EXPORT ---
  String generateSpiceNetlist() {
    if (_latestNodes.isEmpty) return '* Empty Circuit';
    
    Map<String, int> nodeIdMap = {};
    int nextId = 1;
    
    // Find all ground pins
    final Set<String> groundPinIds = {};
    for (var comp in _activeComponents.values) {
      if (comp is Ground) {
        for (var pin in comp.pins) {
          groundPinIds.add(pin.id);
        }
      }
    }
    
    // Assign SPICE node IDs. Ground MUST be 0.
    for (var node in _latestNodes) {
      if (node.connectedPins.any((p) => groundPinIds.contains(p.id))) {
        nodeIdMap[node.id] = 0;
      }
    }
    
    for (var node in _latestNodes) {
      if (!nodeIdMap.containsKey(node.id)) {
        nodeIdMap[node.id] = nextId++;
      }
    }

    StringBuffer sb = StringBuffer();
    sb.writeln('* Notesketch Pro SPICE Export');
    sb.writeln('* Generated from Canvas');
    sb.writeln('');
    
    for (var comp in _activeComponents.values) {
      // Ground doesn't have a SPICE entry, it just provides node 0
      if (comp is Ground) continue; 
      sb.writeln(comp.toSpice(nodeIdMap));
    }
    
    sb.writeln('');
    sb.writeln('.tran 0.1m 10m');
    sb.writeln('.end');
    
    return sb.toString();
  }

  List<Stroke> _runSimulationPass(List<Stroke> strokes) {
    final Map<String, CircuitComponent> nextComponents = {};
    final List<PortalComponent> unlinkedPortals = [];
    
    // Pass 1: Build graph nodes (Components)
    for (var stroke in strokes) {
      if (stroke.toolType == ToolType.text) {
        final existing = _activeComponents[stroke.id];
        if (existing != null && 
            existing.originalStroke.text == stroke.text &&
            existing.originalStroke.size == stroke.size) {
           nextComponents[stroke.id] = existing;
        } else {
           final component = ComponentRegistry().createComponent(stroke);
           if (component != null) {
             nextComponents[stroke.id] = component;
           }
        }
      } else if (stroke.toolType == ToolType.portal) {
        final existing = _activeComponents[stroke.id];
        PortalComponent portalComp;
        if (existing != null && 
            existing.originalStroke.customMetadata?['destinationId'] == stroke.customMetadata?['destinationId']) {
           portalComp = existing as PortalComponent;
           nextComponents[stroke.id] = portalComp;
        } else {
           portalComp = PortalComponent(stroke);
           nextComponents[stroke.id] = portalComp;
        }
        
        if (portalComp.originalStroke.customMetadata?['destinationId'] == null) {
           unlinkedPortals.add(portalComp);
        }
      }
    }
    
    // Auto-link unlinked portals in pairs
    for (var p in unlinkedPortals) {
      p.dynamicDestinationId = null;
    }
    for (int i = 0; i < unlinkedPortals.length - 1; i += 2) {
      unlinkedPortals[i].dynamicDestinationId = unlinkedPortals[i+1].id;
      unlinkedPortals[i+1].dynamicDestinationId = unlinkedPortals[i].id;
    }
    
    _activeComponents.clear();
    _activeComponents.addAll(nextComponents);

    // Pass 2: Node Extraction
    final List<CircuitNode> circuitNodes = [];
    final Map<String, CircuitNode> pinToNode = {};

    CircuitNode getNodeForPin(CircuitPin pin) {
      if (pin.nodeId != null && pinToNode.containsKey(pin.nodeId!)) {
        return pinToNode[pin.nodeId!]!;
      }
      final node = CircuitNode(id: 'node_${circuitNodes.length}');
      node.addPin(pin);
      pin.nodeId = node.id;
      circuitNodes.add(node);
      pinToNode[node.id] = node;
      return node;
    }

    // Connect pins based on wires
    for (var stroke in strokes) {
      if (stroke.toolType == ToolType.wire) {
        final sourceId = stroke.customMetadata?['sourceId'] as String?;
        final targetId = stroke.customMetadata?['targetId'] as String?;
        final sourcePinId = stroke.customMetadata?['sourcePinId'] as String?;
        final targetPinId = stroke.customMetadata?['targetPinId'] as String?;
        
        if (sourceId != null && targetId != null && _activeComponents.containsKey(sourceId) && _activeComponents.containsKey(targetId)) {
          final sourceComp = _activeComponents[sourceId]!;
          final targetComp = _activeComponents[targetId]!;
          
          final sourcePin = sourcePinId != null 
              ? sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == sourcePinId, orElse: () => null)
              : sourceComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.output, orElse: () => null);
              
          final targetPin = targetPinId != null 
              ? targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.id == targetPinId, orElse: () => null)
              : targetComp.pins.cast<CircuitPin?>().firstWhere((p) => p?.direction == PortDirection.input, orElse: () => null);
          
          if (sourcePin != null && targetPin != null) {
            CircuitNode sourceNode = getNodeForPin(sourcePin);
            CircuitNode targetNode = getNodeForPin(targetPin);

            if (sourceNode.id != targetNode.id) {
              // Merge targetNode into sourceNode
              sourceNode.mergeWith(targetNode);
              for (var p in targetNode.connectedPins) {
                p.nodeId = sourceNode.id;
              }
              circuitNodes.remove(targetNode);
              pinToNode.remove(targetNode.id);
            }
          }
        }
      }
    }

    // Create a node for any unconnected pins
    for (var comp in _activeComponents.values) {
      for (var pin in comp.pins) {
        if (pin.nodeId == null || !pinToNode.containsKey(pin.nodeId!)) {
          getNodeForPin(pin);
        }
      }
    }
    
    // Save latest nodes for probing/exporting
    _latestNodes = circuitNodes;

    // Pass 3: MNA Solver Execution
    final solver = MNASolver(circuitNodes);
    
    // Step A: Register voltage sources
    for (var comp in _activeComponents.values) {
      if (comp is Ground) {
        for (var pin in comp.pins) {
          if (pin.nodeId != null) {
            pinToNode[pin.nodeId!]!.isFixed = true; // Ground fixes node to 0V
          }
        }
      } else {
        comp.applyMNA(solver); // Pass 1
      }
    }

    // Step B: Init Matrices
    solver.initMatrices();

    // Step C: Stamp matrices
    for (var comp in _activeComponents.values) {
      if (comp is! Ground) {
        comp.applyMNA(solver); // Pass 2
      }
    }

    // Step D: Solve
    solver.solve();

    // Legacy evaluation pass (for UI colors, motor rotation, etc.)
    final tick = SimulationTick(tickCount: 0, deltaTimeSeconds: 0.16);
    for (var comp in _activeComponents.values) {
      comp.evaluate(tick);
    }

    // Pass 4: Visual Updates & Bezier Wire Generation
    final List<Stroke> updatedStrokes = [];
    for (var stroke in strokes) {
      if (_activeComponents.containsKey(stroke.id)) {
        final comp = _activeComponents[stroke.id]!;
        final targetColor = comp.getActiveColor();
        Map<String, dynamic>? newMetadata = stroke.customMetadata;
        
        if (comp is Oscilloscope) {
          newMetadata = Map.from(stroke.customMetadata ?? {});
          newMetadata['history'] = List<double>.from(comp.voltageHistory);
        }

        if (stroke.color != targetColor || (comp is Oscilloscope)) {
          updatedStrokes.add(stroke.copyWith(
            color: targetColor,
            version: stroke.version + 1,
            customMetadata: newMetadata,
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

            if (stroke.color != targetColor || stroke.points.length != bezierPoints.length || (stroke.points.isNotEmpty && stroke.points.first != bezierPoints.first) || stroke.size != 4.0) {
              updatedStrokes.add(stroke.copyWith(
                color: targetColor,
                points: bezierPoints,
                size: 4.0, // Force a sleek size for autowires!
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
