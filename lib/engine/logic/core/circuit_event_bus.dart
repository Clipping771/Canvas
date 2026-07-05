import 'dart:async';

enum CircuitEventType {
  pinStateChanged,
  componentAdded,
  componentRemoved,
  wireConnected,
  wireDisconnected,
  simulationTick,
}

class CircuitEvent {
  final CircuitEventType type;
  final String sourceId;
  final dynamic payload;
  
  CircuitEvent({
    required this.type,
    required this.sourceId,
    this.payload,
  });
}

class CircuitEventBus {
  static final CircuitEventBus _instance = CircuitEventBus._internal();
  factory CircuitEventBus() => _instance;
  CircuitEventBus._internal();

  final _controller = StreamController<CircuitEvent>.broadcast();
  
  Stream<CircuitEvent> get stream => _controller.stream;
  
  void fire(CircuitEvent event) {
    _controller.add(event);
  }
  
  void dispose() {
    _controller.close();
  }
}
