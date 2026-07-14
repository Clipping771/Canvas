# 03 - Domain Model

This document establishes the **Ubiquitous Language** for Vinci Board. If a term is not defined here, it should not exist in the Core Platform code.

## The Canvas Domain
- **Workspace:** The absolute root. A serialization boundary representing one saved file or collaborative session.
- **Canvas:** The infinite spatial coordinate system. Knows only about X/Y coordinates and zoom levels.
- **SpatialNode:** The base class for *everything* that exists on a Canvas.
  - *Subtypes:* `StrokeNode` (user drawing), `EntityNode` (a loaded 3D molecule or image), `PortalNode` (a window to another Workspace).

## The Engineering Domain
- **EventBus:** The asynchronous messaging system that decouples the UI from the logic.
- **Engine:** A self-contained module that listens to the EventBus, performs domain-specific logic (e.g., Chemistry parsing), and emits new events.
- **Port:** An interface defined by the Core (e.g., `IAiProviderPort`) that dictates how external services must behave.
- **Adapter:** A concrete implementation of a Port (e.g., `GeminiProAdapter`) that sits completely outside the Core.

## The Education Domain
- **LearningFramework:** A hierarchical structure of educational standards, heavily nested (Subject -> Strand -> Topic -> Standard).
- **CurriculumAdapter:** Since every country/state has different standards, the curriculum is never hardcoded. It is loaded via adapters (e.g., `AustralianCurriculumAdapter`).
