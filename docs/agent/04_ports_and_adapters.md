# 04 - Ports & Adapters Specification

> **The Golden Rule:** Stable Core. Replaceable Everything Else.

The Core Platform must never import an external library for AI, Database, Authentication, or Curriculum mapping.

## 1. Abstract Ports (Interfaces inside the Core)
The Core defines exactly what it needs to survive.

```dart
// Example: Core doesn't care if it's Firebase or SQLite.
abstract class IStoragePort {
  Future<void> saveWorkspace(Workspace workspace);
  Future<Workspace> loadWorkspace(String id);
}

// Example: Core doesn't care if it's Gemini or OpenAI.
abstract class IAiProviderPort {
  Future<AiResponse> evaluateAnswer(AiRequest request);
  Future<AiResponse> detectIntent(AiRequest request);
}
```

## 2. Concrete Adapters (Implementations outside the Core)
Adapters live in the outer ring of the Hexagonal architecture. They implement the Ports.

### Current Required Adapters
- `FirebaseStorageAdapter` implements `IStoragePort`
- `LocalHiveStorageAdapter` implements `IStoragePort`
- `GeminiAiAdapter` implements `IAiProviderPort`
- `OnDeviceTfLiteAdapter` implements `IAiProviderPort`

## 3. Dependency Injection
We will use **Riverpod** to inject the correct Adapter into the Port at runtime.
This means for tests, we can inject a `MockAiAdapter` and test the entire application offline in milliseconds.
