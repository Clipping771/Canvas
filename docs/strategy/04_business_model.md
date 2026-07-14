# 04 - Business Model & Strategy

## 1. The Economic Engine (B2B SaaS)
Vinci Board is not a B2C app for students. Student acquisition costs (CAC) are too high, and their willingness to pay (WTP) is too low. The product is a **B2B SaaS platform for Schools and Districts.**

### The Trojan Horse Strategy (Bottom-Up)
1. **The Hook:** Individual teachers (like Sarah) find the product online. They use a restricted "Freemium" version to create a visual lesson and grade a small assignment. It saves them 2 hours.
2. **The Spread:** Sarah tells the other 3 science teachers in her department. They all start using the free tier.
3. **The Upsell (Land and Expand):** The free tier limits AI grading to 50 submissions per month. Once the science department hits this limit, the Head of Department takes the software to the IT Director (Mark) to purchase a "Department License" from their discretionary budget.

## 2. Configurable Entitlement Tiers
Because the platform is built on adapters, our Entitlement Engine can dynamically enable/disable features without branching the codebase.

| Tier | Target | Key Features | LLM Strategy |
| :--- | :--- | :--- | :--- |
| **Freemium** | Solo Teacher | Basic Canvas, 50 AI grades/mo, Local Storage | Relies heavily on Local TFLite to minimize our server costs. |
| **Pro** | Department | Unlimited AI Grading, Shared Lesson Library, Cloud Sync | Uses Cloud LLM (Gemini/OpenAI). Cost is offset by subscription fee. |
| **Enterprise** | School District | LMS Integration (Canvas/Google), SSO, Compliance Dashboards, Custom AI Guardrails | Dedicated Enterprise LLM instances for data privacy. |

## 3. The LLM Cost Risk
Our biggest variable cost is Cloud AI tokens. 
- **Mitigation:** The architecture mandates a **Hybrid Model**. Every time a task can be pushed to the on-device TFLite model (e.g., intent routing, basic stroke classification), we save Cloud API costs. The Cloud LLM is strictly reserved for deep conceptual grading and generation.
