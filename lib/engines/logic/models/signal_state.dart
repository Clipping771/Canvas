import 'package:vinci_board/engines/logic/models/logic_state.dart';

class SignalState {
  LogicState logic;
  double voltage;
  double current;
  double resistance;
  double frequency;
  double dutyCycle;
  double phase;

  SignalState({
    this.logic = LogicState.floating,
    this.voltage = 0.0,
    this.current = 0.0,
    this.resistance = double.infinity,
    this.frequency = 0.0,
    this.dutyCycle = 0.0,
    this.phase = 0.0,
  });

  SignalState copyWith({
    LogicState? logic,
    double? voltage,
    double? current,
    double? resistance,
    double? frequency,
    double? dutyCycle,
    double? phase,
  }) {
    return SignalState(
      logic: logic ?? this.logic,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      resistance: resistance ?? this.resistance,
      frequency: frequency ?? this.frequency,
      dutyCycle: dutyCycle ?? this.dutyCycle,
      phase: phase ?? this.phase,
    );
  }
}
