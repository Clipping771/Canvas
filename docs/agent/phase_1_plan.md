# Phase 1: The Core Foundation - Implementation Plan

We are now moving from the Strategic Documentation Phase into actual codebase execution. Based on our newly baselined Engineering Constitution, the current `lib/` directory is out of sync with our Hexagonal Event-Driven architecture and lacks the required immutability tools.

## Goal
Implement Phase 1 of the Long-Term Roadmap:
- Restructure `lib/` to match the Hexagonal architecture.
- Install `freezed` and configure immutable state.
- Implement the Core EventBus.
- Establish the `IStoragePort` and `IAiProviderPort` interfaces.

## Proposed Changes

### 1. Dependencies
- Run `flutter pub add freezed_annotation`
- Run `flutter pub add --dev build_runner freezed`

### 2. Directory Restructure
Create the new folder structure and begin migrating files into it.
- `lib/core/` (EventBus, Base Nodes, Ports)
- `lib/engines/` (Feature logic like AI or Chemistry)
- `lib/adapters/` (Firebase, Gemini implementations)
- `lib/presentation/` (Flutter Widgets, Screens, Riverpod UI)
*(Note: The old directories models, providers, screens, services, utils, widgets will be incrementally moved into these 4 folders and then deleted).*

### 3. Core Package Implementation
- `lib/core/events/base_event.dart`: Create the Freezed base event classes.
- `lib/core/event_bus.dart`: Implement the `EventBus` using Riverpod `StreamController`.
- `lib/core/ports/i_storage_port.dart`: Define the abstract interface for saving/loading.
- `lib/core/ports/i_ai_provider_port.dart`: Define the abstract interface for the AI engine.
