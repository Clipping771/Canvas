# 00 - Project Governance

## 1. Document Lifecycle
All strategic and architectural documents must follow this strict lifecycle:
1. **Draft:** Initial creation by the AI Agent or Human Owner.
2. **Review:** Internal review by the engineering team, followed by external validation (where appropriate).
3. **Approved:** Formal approval by the Product Owner.
4. **Baseline:** The document becomes the source of truth for downstream execution. (Code generation is permitted only against baselined specs).
5. **Superseded:** Replaced by a newer version following a significant architectural pivot.

## 2. Ownership & Authority
- **Product Owner (Human):** Holds ultimate decision authority. Responsible for approving architecture, providing external validation results, and defining the business model.
- **Lead Architect / Implementer (AI Agent):** Responsible for proposing architectures, drafting specifications, writing code against baselined documents, and enforcing the Golden Rule.

## 3. Milestones & Timeline
The project is divided into iterative sprints, focusing on establishing the platform architecture before any product code is written.

*   **Sprint 0: Strategy & Foundations**
    *   Goal: Define the "What" and "Why".
    *   Exit Criteria: Domain Model and PRD are baselined.
*   **Sprint 1: Agentic Rulebook & Contracts**
    *   Goal: Establish the rules of engagement for AI-driven development.
    *   Exit Criteria: Definition of Done and Ports & Adapters specifications are baselined.
*   **Sprint 2: Workflow & Curriculum Specifications**
    *   Goal: Detail the hierarchical learning framework.
    *   Exit Criteria: Curriculum architecture and Workflows are baselined.
*   **Sprint 3: Execution, Risk & Future Planning**
    *   Goal: Prepare for long-term scalability and track decisions.
    *   Exit Criteria: ADR log initialized, Assumption Register populated.

## 4. Verification Gates
No architectural decision or code implementation may be merged without passing the 5 Verification Gates:
1. Can this vary by country?
2. Can this vary by school?
3. Can this vary by provider?
4. Can this vary in the future?
5. Does this belong in the immutable core?

*(If 1-4 are YES, it must be implemented via configuration, adapter, registry, or plugin).*

## 5. External Validation Plan
Before the baseline of Workflow and Curriculum documents (Sprint 2), the Product Owner must validate the assumptions with actual stakeholders (Teachers, Students, and potentially Parents) to ensure the technical architecture aligns with market reality.

> **Exception:** For student or exploratory projects, Sprint 2 documents may be baselined as design hypotheses prior to external validation. Market assumptions remain tracked in the Assumption Register until empirically validated.
