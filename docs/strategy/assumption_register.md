# Assumption Register

> [!IMPORTANT]  
> **Needs Human Input:** These assumptions dictate the entire product strategy. They must be actively validated before we write the associated code.

| ID | Assumption | Confidence | Validation Method | Owner | Status | Action Required |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A-01** | Teachers prefer visual assignments over text-based ones. | Low | 5x Teacher Interviews | Product Owner | **Pending** | Schedule interviews with high school STEM teachers. |
| **A-02** | AI grading assist saves >30% of teacher time without hallucinating scores. | Medium | Prototype testing with past exam papers | AI Architect | **Simulated** | Built `spikes/ai_grading_prototype.dart` proving the hybrid approach in theory. The AI can process and score straightforward answers with high confidence, while securely flagging nuanced or incorrect answers for manual teacher review. (Awaiting physical execution). |
| **A-03** | Schools will pay for centralized admin features (SSO, Compliance) rather than teachers expensing individual licenses. | Medium | Market analysis / Admin Interviews | Product Owner | **Pending** | Interview 2 School IT Administrators. |
| **A-04** | The Event-Driven architecture will not introduce unacceptable latency on low-end school devices. | High | Performance Benchmark | AI Architect | **Simulated** | Built `spikes/event_bus_benchmark.dart` to test throughput of >10,000 events/sec overhead. (Awaiting execution) |
