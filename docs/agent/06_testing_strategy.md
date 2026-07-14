# 06 - Testing Strategy

Vinci Board utilizes a rigorous Testing Strategy to ensure the "Stable Core" remains bulletproof, while allowing rapid iteration on the Adapters.

## 1. Domain Unit Tests (Core & Engines)
- **Target:** The Core EventBus, Spatial Math, and isolated Engine logic.
- **Rule:** These tests must execute in < 1 second. No I/O, no network calls, no Flutter UI.
- **Method:** We inject a `MockEventBus` into an Engine, fire an event, and assert that the Engine emits the correct response event.

## 2. Port & Adapter Contract Tests (Adapters)
- **Target:** The outer ring (Firebase, Gemini).
- **Rule:** If we swap `GeminiAdapter` for `OpenAiAdapter`, we must be mathematically certain the app won't break.
- **Method:** We write a single suite of tests against `IAiProviderPort`. Both the Gemini and OpenAI adapters must pass this identical test suite (proving they honor the contract).

## 3. UI Widget Tests (Presentation)
- **Target:** Flutter UI components.
- **Rule:** Widgets are tested strictly by overriding Riverpod providers with mocked states. We do not test the actual Firebase connection when testing a login button.

## 4. AI Prompt Regression Testing
- **Target:** The `prompt_library`.
- **Rule:** Because LLMs are non-deterministic, any change to a prompt (e.g., grading rubric) must be run against a static batch of 50 past exam papers to ensure the accuracy (measured in `spikes/ai_grading_prototype.dart`) does not degrade.
