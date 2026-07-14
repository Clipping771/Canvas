# 03 - Definition of Done (DoD)

An Agent cannot mark a task as `Done` until it meets ALL of the following criteria:

## 1. Architectural Integrity
- [ ] No `core/` file imports anything from `adapters/` or `presentation/`.
- [ ] No direct dependencies exist between different `engines/` (they must communicate via the EventBus).

## 2. State & Safety
- [ ] All new state is immutable (using `freezed`).
- [ ] Edge cases (e.g., Network failure when calling an LLM) are caught and handled gracefully without crashing the UI.

## 3. Testing
- [ ] **Unit Tests:** Any new Engine logic is tested in isolation (mocking the EventBus).
- [ ] **Contract Tests:** Any new Adapter passes the contract tests defined by its Port.

## 4. Human Verification
- [ ] The Product Owner has reviewed the PR or the Agent's architectural summary and explicitly approved the implementation.
