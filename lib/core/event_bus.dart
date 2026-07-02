import 'dart:async';

enum EventType {
  canvasUpdated,
  physicsTriggered,
  aiClarificationNeeded,
  aiTaskCompleted,
  aiActionDispatched,
  environmentChanged,
  systemError,
  cancelGeneration,
}

class CanvasEvent {
  final EventType type;
  final dynamic payload;
  final DateTime timestamp;

  CanvasEvent(this.type, {this.payload}) : timestamp = DateTime.now();
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _streamController = StreamController<CanvasEvent>.broadcast();

  Stream<CanvasEvent> get stream => _streamController.stream;

  void publish(EventType type, [dynamic payload]) {
    _streamController.add(CanvasEvent(type, payload: payload));
  }

  StreamSubscription<CanvasEvent> subscribe(
    EventType type,
    void Function(CanvasEvent event) handler,
  ) {
    return _streamController.stream
        .where((event) => event.type == type)
        .listen(handler);
  }

  void dispose() {
    _streamController.close();
  }
}
