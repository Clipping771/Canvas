import 'package:flutter/material.dart';
import '../../../../models/stroke.dart';
import '../core/simulation_tick.dart';
import 'circuit_pin.dart';

abstract class CircuitComponent {
  final String id;
  final Stroke originalStroke;

  CircuitComponent({
    required this.id,
    required this.originalStroke,
  });

  String get name;
  List<String> get aliases;
  Map<String, dynamic> get metadata;
  List<CircuitPin> get pins;

  void evaluate(SimulationTick tick);

  Color getActiveColor();
  
  bool get isAnimated => false;
}
