import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'event_bus.dart';

class EventLogger {
  static final EventLogger _instance = EventLogger._internal();
  factory EventLogger() => _instance;
  EventLogger._internal();

  final List<CanvasEvent> _eventLog = [];
  bool isLoggingEnabled = true;

  void init() {
    EventBus().stream.listen((event) {
      if (isLoggingEnabled) {
        _eventLog.add(event);
        _printLog(event);
      }
    });
  }

  void _printLog(CanvasEvent event) {
    if (kDebugMode) {
      String payloadStr = '';
      if (event.payload != null) {
        try {
          payloadStr = ' | Payload: ${jsonEncode(event.payload)}';
        } catch (_) {
          payloadStr = ' | Payload: ${event.payload.toString()}';
        }
      }
      debugPrint('[EventLogger] ${event.timestamp.toIso8601String()} - ${event.type.name}$payloadStr');
    }
  }

  List<CanvasEvent> getEventHistory() {
    return List.unmodifiable(_eventLog);
  }

  void clearLogs() {
    _eventLog.clear();
  }
}
