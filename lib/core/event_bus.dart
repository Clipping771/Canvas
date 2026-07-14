import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/events/base_event.dart';

class EventBus {
  final _controller = StreamController<BaseEvent>.broadcast();

  Stream<BaseEvent> get stream => _controller.stream;

  void publish(BaseEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

final eventBusProvider = Provider<EventBus>((ref) {
  final eventBus = EventBus();
  ref.onDispose(() => eventBus.dispose());
  return eventBus;
});
