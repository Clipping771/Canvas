import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../models/circuit_component.dart';
import '../models/circuit_pin.dart';
import '../models/logic_state.dart';
import '../models/signal_state.dart';
import '../core/simulation_tick.dart';
import '../core/mna_solver.dart';

class ComponentDefinition {
  final String name;
  final List<String> aliases;
  final Map<String, dynamic> defaultMetadata;
  final List<Map<String, dynamic>> pinDefinitions;
  final Map<String, dynamic>? mnaModel; // Contains 'type' (e.g. 'resistor', 'voltage_source') and 'valueField'

  ComponentDefinition({
    required this.name,
    required this.aliases,
    required this.defaultMetadata,
    required this.pinDefinitions,
    this.mnaModel,
  });

  factory ComponentDefinition.fromJson(Map<String, dynamic> json) {
    return ComponentDefinition(
      name: json['name'],
      aliases: List<String>.from(json['aliases'] ?? []),
      defaultMetadata: Map<String, dynamic>.from(json['defaultMetadata'] ?? {}),
      pinDefinitions: List<Map<String, dynamic>>.from(json['pins'] ?? []),
      mnaModel: json['mnaModel'],
    );
  }
}

class GenericComponent extends CircuitComponent {
  final ComponentDefinition definition;
  late final List<CircuitPin> _pins;
  late final Map<String, dynamic> _metadata;
  int? _vSourceIndex;

  @override
  String get name => definition.name;

  @override
  List<String> get aliases => definition.aliases;

  @override
  Map<String, dynamic> get metadata => _metadata;

  @override
  List<CircuitPin> get pins => _pins;

  GenericComponent(Stroke stroke, this.definition) : super(id: stroke.id, originalStroke: stroke) {
    _metadata = Map.from(definition.defaultMetadata);
    
    // Simple text parsing for properties (e.g., if there's a regex in the definition)
    // For now, we'll just check if there's a simple number parsing needed
    
    double halfWidth = 50.0;
    if (stroke.text != null) {
      halfWidth = (stroke.text!.length * (stroke.size * 0.6)) / 2.0 + 10.0;
    }

    _pins = definition.pinDefinitions.map((pDef) {
      final isInput = pDef['direction'] == 'input';
      final isOutput = pDef['direction'] == 'output';
      
      final dxStr = pDef['relativePosition']?['dx'] ?? '0';
      final dyStr = pDef['relativePosition']?['dy'] ?? '0';
      
      // Dynamic positioning based on halfWidth if defined as 'left' or 'right'
      double dx = 0.0;
      if (dxStr == 'left') dx = -halfWidth;
      else if (dxStr == 'right') dx = halfWidth;
      else dx = double.tryParse(dxStr.toString()) ?? 0.0;
      
      return CircuitPin(
        id: '${id}_${pDef['id']}',
        name: pDef['name'],
        direction: isInput ? PortDirection.input : (isOutput ? PortDirection.output : PortDirection.bidirectional),
        relativePosition: Offset(dx, double.tryParse(dyStr.toString()) ?? 0.0),
      );
    }).toList();
  }

  @override
  void updatePropertiesFromText(String text) {
    // If the component definition has a regex parser, we can use it here
    if (definition.mnaModel != null && definition.mnaModel!['parseRegex'] != null) {
      final regex = RegExp(definition.mnaModel!['parseRegex'], caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = double.tryParse(match.group(1)!);
        if (val != null) {
          final targetField = definition.mnaModel!['valueField'];
          if (targetField != null) {
            _metadata[targetField] = val;
          }
        }
      }
    }
  }

  @override
  void applyMNA(dynamic solver) {
    if (solver is! MNASolver || definition.mnaModel == null) return;
    
    final modelType = definition.mnaModel!['type'];
    final valueField = definition.mnaModel!['valueField'];
    final val = _metadata[valueField] ?? 0.0;
    
    if (modelType == 'voltage_source') {
      if (_vSourceIndex == null) {
        _vSourceIndex = solver.registerVoltageSource();
      } else if (_pins.length >= 2) {
        solver.addVoltageSource(_vSourceIndex!, _pins[0].nodeId, _pins[1].nodeId, val);
      }
    } else if (modelType == 'resistor') {
      if (_pins.length >= 2) {
        double conductance = 1.0 / (val > 0.001 ? val : 0.001);
        solver.addConductance(_pins[0].nodeId, _pins[1].nodeId, conductance);
      }
    }
  }

  @override
  void evaluate(SimulationTick tick) {
    // Basic logic mapping if defined, else MNA handles it
  }

  @override
  Color getActiveColor() => Colors.white;
}
