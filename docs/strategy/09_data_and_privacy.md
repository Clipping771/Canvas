# 09 - Data & Privacy Architecture

Selling to schools requires ironclad privacy compliance (FERPA in the US, GDPR in Europe, etc.). 

## 1. Privacy By Design (Local-First)
Vinci Board is fundamentally a **Local-First** application.
- All canvas strokes, interactions, and basic AI processing (Tier 1 TFLite) happen entirely on the device.
- We do not transmit continuous telemetry of student behavior to the cloud.

## 2. Cloud LLM PII Scrubbing
Before any context is sent to a Tier 2 Cloud LLM (e.g., Gemini/OpenAI):
1. The `AiIntentEngine` strips all Personally Identifiable Information (PII) from the payload.
2. The payload is anonymized with a session UUID, not a student ID.
3. We explicitly mandate zero-retention policies via our Enterprise agreements with AI Providers.

## 3. The Compliance Adapter
Because privacy laws vary by country, compliance is handled via Adapters, injected based on the user's location setting.
- `GdprComplianceAdapter`: Enforces strict right-to-be-forgotten and explicit consent flows.
- `CoppaComplianceAdapter`: Enforces parental consent gates for users under 13.
- If a school (the Buyer) dictates a policy, it overrides the platform defaults via the Configuration Hierarchy.
