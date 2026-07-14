# 01 - Product Requirements Document (PRD)

## 1. Executive Summary & Vision
Vinci Board is not just a digital whiteboard; it is a **Curriculum-Aware spatial learning platform** designed initially for high school STEM education. The vision is to build an environment where the curriculum, physics simulations, AI providers, and educational workflows are replaceable modules built upon a highly stable, event-driven core. 

## 2. Positioning & The "Wedge"
**The Problem:** Google Classroom is great for management but terrible for content creation. Microsoft OneNote is a great blank canvas but has zero understanding of the curriculum or the subjects being taught on it. 
**The Solution (Our Wedge):** Vinci Board acts as the bridge. It is an **AI Visual Learning Workspace**. When a student draws a chemical bond, the platform *knows* it's chemistry, validates it against the curriculum, and provides contextual feedback. 

## 3. Target Audience & Adoption Strategy
- **Primary Persona:** The High School STEM Teacher (Year 7 - 12).
- **Adoption Strategy:** Bottom-up. We must provide tools (e.g., AI automated grading of visual diagrams, 1-click interactive lesson generation) that immediately reduce a teacher's out-of-hours workload. If the teacher adopts it, they will mandate their students use it to complete assignments, driving student acquisition for free.

## 4. Core Epics (Phase 1)
1. **The Event-Driven Canvas:** An infinite spatial canvas that broadcasts user actions (strokes, object placement) to listening engines.
2. **The Hexagonal Engine System:** The ability to load isolated "Engines" (Chemistry, Physics) that react to canvas events without being hardcoded into the UI.
3. **Hybrid AI Orchestration:** A pipeline where fast intent-detection runs locally (on-device), and complex Socratic tutoring runs via cloud LLMs.
4. **Adapter-based Storage & Auth:** All file saving and user management must be behind strict interfaces to allow swapping from local storage to Firebase to Enterprise SSO.

## 5. Non-Goals (Out of Scope for Phase 1)
- Building our own proprietary LLM. We will use adapters for existing models (Gemini, OpenAI).
- Replacing standard School Information Systems (SIS) like Canvas LMS or Google Classroom. We will eventually integrate with them via adapters, not replace them.
- Non-STEM subjects (History, English). The initial focus is strictly on visual, simulation-heavy subjects.
