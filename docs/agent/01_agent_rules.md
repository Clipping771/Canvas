# 01 - Agent Rules

These rules dictate the behavior of any AI Agent (Antigravity, GitHub Copilot, etc.) writing code in the Vinci Board repository.

## 1. Absolute Directives
1. **Agents Implement, Humans Approve:** Agents must never merge architectural changes or create new foundational domain models without the Product Owner's explicit written approval in a baselined spec.
2. **The Hexagonal Mandate:** Never import a Flutter UI widget (`package:flutter/material.dart`) or a specific database package (`package:firebase_core/...`) into a file located in `lib/core/`.
3. **No Phantom State:** Do not use `StatefulWidget` to store core business logic. All state must live in Riverpod Providers or the EventBus.
4. **No God Classes:** Agents must aggressively break down logic. If an Engine exceeds 300 lines, it must be refactored into smaller, composed modules.

## 2. Failure Protocol
If an Agent is asked to implement a feature but realizes it violates the Hexagonal Architecture (e.g., "Add Google Sign-In button to the Canvas"):
1. The Agent must STOP.
2. The Agent must refuse the instruction.
3. The Agent must propose an Adapter-based alternative (e.g., "Create an `IAuthPort` in the core, fire a `LoginRequestedEvent`, and handle the Google UI in the outer ring").
