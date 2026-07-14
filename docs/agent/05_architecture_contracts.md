# 05 - Architecture Contracts

Contracts define exactly how the Core communicates with Engines, ensuring they remain decoupled. An Agent must review these contracts before implementing a new Engine.

## Contract 1: The Canvas Engine
- **Role:** Pure renderer and spatial math calculator.
- **Input Events:** `UiTapEvent`, `UiPanEvent`, `StateUpdatedEvent` (from other engines).
- **Output Events:** `NodeSelectedEvent`, `StrokeCompletedEvent`, `CanvasViewChangedEvent`.
- **Constraint:** The Canvas Engine is "dumb". If a user draws a molecule, the Canvas Engine only knows a `StrokeNode` was drawn. It is up to the `AiIntentEngine` to classify it.

## Contract 2: The Event Bus
- **Role:** The sole communication channel.
- **Constraint:** Events must be fire-and-forget. An Engine must never await a response directly from the Event Bus. If an Engine needs a response (e.g., waiting for an AI calculation), it must listen for an `AiCalculationCompletedEvent` later in time.

## Contract 3: Engine Boundaries
- **Role:** Isolated feature logic (e.g., `ChemistryEngine`).
- **Constraint:** An Engine cannot hold a reference to another Engine. They only know about the Event Bus.
