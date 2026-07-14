import 'dart:async';
import 'package:vinci_board/engines/logic/core/circuit_event_bus.dart';
import 'package:vinci_board/engines/logic/core/simulation_tick.dart';

class SimulationScheduler {
  static final SimulationScheduler _instance = SimulationScheduler._internal();
  factory SimulationScheduler() => _instance;
  SimulationScheduler._internal();

  Timer? _timer;
  int _tickCount = 0;
  final double _tickIntervalMs = 1000 / 60.0; // 60 FPS target

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(Duration(milliseconds: _tickIntervalMs.round()), (
      timer,
    ) {
      _tick();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  void _tick() {
    _tickCount++;
    final tick = SimulationTick(
      tickCount: _tickCount,
      deltaTimeSeconds: _tickIntervalMs / 1000.0,
    );
    CircuitEventBus().fire(
      CircuitEvent(
        type: CircuitEventType.simulationTick,
        sourceId: 'scheduler',
        payload: tick,
      ),
    );
  }
}
