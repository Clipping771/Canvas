# 02 - Coding Standards

## 1. Language & Framework
- **Dart 3.x:** Utilize pattern matching, records, and sealed classes heavily for event definitions.
- **Flutter:** Used strictly for the "Outer Ring" (presentation layer).

## 2. State Management & Injection
- **Riverpod:** The exclusive dependency injection and state management tool.
- Use `@riverpod` code generation for all providers.
- **NEVER** pass dependencies manually through constructors if a Riverpod provider exists for it.

## 3. Data Immutability
- All models passed through the EventBus MUST be deeply immutable.
- Use the `freezed` package for all domain models and events.
- Example:
  ```dart
  @freezed
  class SpatialEvent with _\$SpatialEvent {
    const factory SpatialEvent.nodeMoved(String id, double x, double y) = _NodeMoved;
  }
  ```

## 4. Directory Structure
```text
lib/
├── core/             # Immutable. Contains EventBus, abstract Ports, and base SpatialNodes.
├── engines/          # Feature logic. Listens to EventBus. (e.g., chemistry_engine/)
├── adapters/         # Concrete implementations of Ports (e.g., gemini_adapter/)
├── presentation/     # Flutter UI. Riverpod widgets. No business logic.
└── main.dart         # Wires Adapters into Ports via Riverpod overrides.
```
