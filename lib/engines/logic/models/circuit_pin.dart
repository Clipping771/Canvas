import 'package:flutter/material.dart';
import 'package:vinci_board/engines/logic/models/signal_state.dart';
import 'package:vinci_board/engines/logic/models/logic_state.dart';

enum PortDirection { input, output, bidirectional }

class CircuitPin {
  final String id;
  final String name;
  final PortDirection direction;
  final Offset
  relativePosition; // Offset relative to the component's center/bounds
  SignalState state;
  String?
  nodeId; // The ID of the CircuitNode this pin is electrically connected to
  bool isDigital;

  CircuitPin({
    required this.id,
    required this.name,
    required this.direction,
    required this.relativePosition,
    this.isDigital = false,
    SignalState? state,
  }) : state = state ?? SignalState();

  // Bridging Analog to Digital
  void bridgeToDigital() {
    if (isDigital) {
      state.logic = state.voltage > 2.5 ? LogicState.high : LogicState.low;
    }
  }
}
