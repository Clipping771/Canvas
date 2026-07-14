import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/event_bus.dart';
import 'package:vinci_board/core/events/base_event.dart';

class EventLogger {
  static final EventLogger _instance = EventLogger._internal();
  factory EventLogger() => _instance;
  EventLogger._internal();

  static const int _maxLogSize = 500;

  final List<BaseEvent> _eventLog = [];
  bool isLoggingEnabled = true;
  StreamSubscription<BaseEvent>? _eventSubscription;
  EventBus? _eventBus;

  /// Subscribes this logger to the application event stream.
  /// Use the shared EventBus instance provided by [eventBusProvider] for
  /// application-wide event communication. Creating a new EventBus instance
  /// results in an independent event stream.
  /// This method is idempotent: repeated calls with the same [eventBus]
  /// instance are no-ops. A different instance cancels the prior subscription
  /// before resubscribing.
  void init(EventBus eventBus) {
    if (identical(_eventBus, eventBus) && _eventSubscription != null) return;
    _eventSubscription?.cancel();
    _eventBus = eventBus;
    _eventSubscription = eventBus.stream.listen((event) {
      if (isLoggingEnabled) {
        _eventLog.add(event);
        if (_eventLog.length > _maxLogSize) _eventLog.removeAt(0);
        _printLog(event);
      }
    });
  }

  /// Cancels the active event subscription. Call when the logger is no longer needed.
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventBus = null;
  }

  void _printLog(BaseEvent event) {
    if (kDebugMode) {
      String payloadStr = '';
      try {
        payloadStr = ' | Payload: ${jsonEncode(event.toString())}';
      } catch (_) {
        payloadStr = ' | Payload: ${event.toString()}';
      }
      debugPrint(
        '[EventLogger] ${DateTime.now().toIso8601String()} - ${event.runtimeType}$payloadStr',
      );
    }
  }

  List<BaseEvent> getEventHistory() {
    return List.unmodifiable(_eventLog);
  }

  void clearLogs() {
    _eventLog.clear();
  }
}

/// Riverpod provider that owns the [EventLogger] lifecycle.
///
/// Reading this provider once is sufficient to activate the logger for the
/// lifetime of the [ProviderScope]. The logger is automatically disposed
/// (subscription cancelled) when the scope is destroyed.
///
/// Activate from the root widget:
/// ```dart
/// ref.read(eventLoggerProvider); // in VinciBoardApp.build or initState
/// ```
final eventLoggerProvider = Provider<EventLogger>((ref) {
  final logger = EventLogger();
  final eventBus = ref.read(eventBusProvider);
  logger.init(eventBus);
  ref.onDispose(logger.dispose);
  return logger;
});
