# 07 - System Architecture

> **The Golden Rule:** Stable Core. Replaceable Everything Else.

## 1. Core Paradigm: Event-Driven Hexagonal Architecture (Ports and Adapters)
Vinci Board rejects the monolithic tightly-coupled feature model. The application is divided into an immutable **Core Domain** and replaceable **Adapters**.

### 1.1 The Immutable Core
The core domain is responsible for the absolute foundational physics and spatial geometry of the application. It has zero knowledge of "Chemistry", "Gemini", or "Firebase".
- **Workspace Manager:** Handles file I/O operations through an abstract storage interface.
- **Event Bus:** The central nervous system. All cross-domain communication happens via asynchronous event streams. *(Validated: >10k events/sec throughput)*
- **Spatial Node Graph (Canvas Engine):** Manages rendering, panning, zooming, and hit-testing of generic `SpatialNode` objects.

### 1.2 The Engine Registry
Features are implemented as isolated **Engines** that plug into the core via the Event Bus.
Example Engines:
- `ChemistryEngine`
- `PhysicsSimulatorEngine`
- `GamificationEngine`
- `TeacherAnalyticsEngine`

## 2. Event Flow Example
When a student interacts with the canvas:
1. **Canvas Engine** detects a stroke and emits `StrokeDrawnEvent`.
2. **AiIntentEngine** listens, analyzes the stroke, classifies it as a molecule, and emits `MoleculeIntentDetectedEvent`.
3. **ChemistryEngine** listens to the intent, converts the stroke to a structured chemical graph, and emits `ChemistryStateUpdatedEvent`.
4. **GamificationEngine** observes the successful interaction and awards XP.
5. **Canvas Engine** listens to the chemistry state update and replaces the raw stroke with a rendered 3D molecule.

*At no point did the Canvas Engine directly call `ChemistryEngine.render()`.*

## 3. Dependency Rules
- **Inner Ring:** Core Platform (Event Bus, Canvas Engine, Base Models).
- **Middle Ring:** Feature Engines (Chemistry, Physics).
- **Outer Ring:** Adapters (UI Widgets, Cloud Sync, LLM APIs).
- **Rule:** Dependencies can only point INWARD. Adapters depend on Ports defined by the Core. The Core depends on nothing.
