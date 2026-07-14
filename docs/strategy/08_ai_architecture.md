# 08 - AI Architecture

> **The Golden Rule:** Stable Core. Replaceable Everything Else.

## 1. Hybrid AI Routing
Vinci Board utilizes a tiered AI strategy to optimize for cost, latency, and offline capability.

### 1.1 Tier 1: Local / On-Device (TFLite)
- **Role:** Fast, continuous processing without network overhead.
- **Use Cases:** Stroke classification, intent detection, basic handwriting recognition, spatial organization.
- **Trigger:** Immediate upon user action.

### 1.2 Tier 2: Cloud LLM (The "Provider")
- **Role:** Deep conceptual understanding and complex generation.
- **Use Cases:** Socratic tutoring, generating diagrams (PlantUML), evaluating free-form exam answers.
- **Implementation:** Must be abstracted behind an `IAiProviderPort` interface (Adapter pattern) so the underlying model (Gemini, Claude, GPT) can be swapped without touching the core.

## 2. AI Orchestration Pipeline
When a complex user action occurs (e.g., asking the AI Chat Panel a question):

1. **Intent Detection:** Local model determines what the user wants (e.g., "Ask a physics question" vs "Draw a molecule").
2. **Planner:** The AI creates a sequence of actions.
3. **Retriever:** Context is gathered from the Canvas Engine (e.g., extracting the text of the currently selected nodes).
4. **Tool Selection:** The AI chooses an action (e.g., `generate_plantuml`, `spawn_spatial_node`).
5. **Action:** The system executes the tool.
6. **Verification (Hybrid Grading):** If acting as a reviewer, the AI provides a confidence score. High confidence triggers automatic feedback. Low confidence safely flags the answer for manual teacher review. *(Validated: Spike A-02)*

## 3. The "I Don't Know" Fallback
AI hallucination is unacceptable in education. The AI Runtime must explicitly include a fallback protocol where the system politely informs the student that it cannot verify the answer and redirects them to their teacher or textbook.
