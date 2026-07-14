import 'package:freezed_annotation/freezed_annotation.dart';

part 'base_event.freezed.dart';

/// Application-wide event sealed class.
///
/// ## Payload Contract for [BaseEvent.generic]
/// The [payload] field is typed as `dynamic` for compatibility with the
/// code-generation layer. All publishers and subscribers must adhere to
/// the following conventions:
///
/// - **Publishers** must always pass a `Map<String, dynamic>` as [payload].
///   Passing a raw primitive, a `List`, or a non-serialisable object is
///   a contract violation.
///
/// - **Subscribers** must cast [payload] defensively:
///   ```dart
///   final p = (event is GenericEvent ? event.payload : null)
///       as Map<String, dynamic>?;
///   ```
///   Never cast without a null check. Never assume key presence.
///
/// - **Event type strings** must be one of the registered constants defined
///   in [EventTypes]. Passing an unregistered string is a contract violation
///   and will produce a `dart:developer log()` warning from [MultiIntentRouter].
///
/// ## Registered Event Types
/// See [EventTypes] for the authoritative list of valid [type] values.
@freezed
class BaseEvent with _$BaseEvent {
  const factory BaseEvent.appStarted() = AppStarted;

  /// A generic named event with an optional structured payload.
  ///
  /// [type] must be a value from [EventTypes].
  /// [payload] must be a `Map<String, dynamic>` — see class-level documentation.
  const factory BaseEvent.generic(String type, {dynamic payload}) =
      GenericEvent;
}

/// Authoritative registry of valid [BaseEvent.generic] type strings.
///
/// All publishers must use constants from this class. Using literal strings
/// outside this registry is a contract violation.
abstract final class EventTypes {
  /// AI task completed — camera focus should update.
  /// Payload keys: `'intent': CameraIntent`
  static const String aiTaskCompleted = 'aiTaskCompleted';

  /// AI action dispatched — e.g. quiz triggered.
  /// Payload keys: `'action': String`, plus action-specific keys.
  static const String aiActionDispatched = 'aiActionDispatched';

  /// Physics engine event triggered by the router.
  /// Payload keys: same as the originating AI op map.
  static const String physicsTriggered = 'physicsTriggered';

  /// Canvas drawing update dispatched by the router.
  /// Payload keys: same as the originating AI op map.
  static const String canvasUpdated = 'canvasUpdated';

  /// AI generation cancellation requested by the user.
  /// Payload: none (empty map or absent).
  static const String cancelGeneration = 'cancelGeneration';

  /// AI spawn completed — camera move may be needed.
  /// Payload keys: `Offset` (spawn position).
  static const String aiSpawnCompleted = 'aiSpawnCompleted';

  /// Engine-level error from the intent router.
  /// Payload keys: `'error': String`, `'action': String`
  static const String systemError = 'systemError';

  /// Application startup event.
  static const String appStarted = 'appStarted';
}
