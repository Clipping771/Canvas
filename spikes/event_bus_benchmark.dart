import 'package:flutter/foundation.dart';
import 'dart:async';

// Simple Event Bus Implementation for the spike
class EventBus {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void publish(Map<String, dynamic> event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

void main() async {
  debugPrint('--- Event Bus Performance Benchmark (A-04) ---');
  final eventBus = EventBus();
  final int totalEvents = 10000;

  // Create 5 dummy listeners representing isolated engines
  int receivedEvents = 0;

  for (int i = 0; i < 5; i++) {
    eventBus.stream.listen((event) {
      if (event['type'] == 'StrokeDrawn') {
        receivedEvents++;
      }
    });
  }

  debugPrint(
    'Starting test: Publishing $totalEvents events to 5 listeners (Expected Total Processed: ${totalEvents * 5})...',
  );

  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < totalEvents; i++) {
    eventBus.publish({'type': 'StrokeDrawn', 'payload': 'test_data_$i'});
  }

  // Allow a tiny delay for stream to process
  await Future.delayed(Duration(milliseconds: 100));
  stopwatch.stop();

  debugPrint(
    'Processed $receivedEvents events in ${stopwatch.elapsedMilliseconds} ms.',
  );

  final eventsPerSecond = (totalEvents / (stopwatch.elapsedMilliseconds / 1000))
      .round();
  debugPrint('Throughput: $eventsPerSecond events published per second.');

  if (eventsPerSecond > 1000) {
    debugPrint(
      '✅ SUCCESS: Event Bus comfortably exceeds 1000 events/sec baseline.',
    );
  } else {
    debugPrint(
      '❌ FAILED: Event Bus performance is below acceptable thresholds.',
    );
  }

  eventBus.dispose();
}
