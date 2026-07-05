import 'package:flutter/material.dart';
import 'signal_state.dart';

enum PortDirection { input, output, bidirectional }

class CircuitPin {
  final String id;
  final String name;
  final PortDirection direction;
  final Offset relativePosition; // Offset relative to the component's center/bounds
  SignalState state;

  CircuitPin({
    required this.id,
    required this.name,
    required this.direction,
    required this.relativePosition,
    SignalState? state,
  }) : state = state ?? SignalState();
}
