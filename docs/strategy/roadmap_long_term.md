# Long-Term Roadmap (12-24 Months)

> **Goal:** Transition from a technical prototype to a scalable B2B EdTech Platform.

## Phase 1: The Core Foundation (Months 1-3)
- Implement the EventBus and basic SpatialNode rendering in Flutter.
- Establish the `IStoragePort` and `IAiProviderPort`.
- **Milestone:** A teacher can drag a node, write text, and save the workspace locally.

## Phase 2: The "Wedge" Features (Months 4-6)
- Develop the `ChemistryEngine` and `PhysicsSimulatorEngine`.
- Integrate the Hybrid AI Model (Local intent routing + Cloud Socratic tutoring).
- **Milestone:** A student can draw a molecule, the system recognizes it, and the AI can grade a basic visual assignment.

## Phase 3: The Classroom Distribution Loop (Months 7-9)
- Implement `ILmsAdapter` (Google Classroom / Canvas LMS integration).
- Build the Teacher Analytics Dashboard (heat-maps of student progress).
- **Milestone:** A teacher can generate a lesson and distribute it to 30 students via a single link.

## Phase 4: Enterprise Scale (Months 10-12)
- Implement SSO and centralized compliance adapters (FERPA/GDPR).
- Build the "School Admin" billing and deployment tier.
- **Milestone:** The first full-school or district-wide deployment.
