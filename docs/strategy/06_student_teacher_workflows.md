# 06 - Student & Teacher Workflows

This document defines the exact UX flows for our primary personas, optimizing heavily for the "Teacher-Led Bottom-Up Adoption" strategy.

## 1. The Teacher Flow (Sarah)
**Goal:** Distribute an interactive assignment in under 5 minutes.
1. **Creation:** Sarah opens an empty Canvas.
2. **AI Assistance:** She types `/generate magnetic_field_quiz`. The AI Provider generates a spatial layout with a pre-configured magnetic field simulation and 3 vector drawing prompts.
3. **Distribution:** Sarah clicks "Share to Classroom" (via `ILmsAdapter`). It generates a unique join code/link.
4. **Review Dashboard:** As students submit, the UI displays a heat-map of the classroom's understanding. 85% of answers are auto-graded. Sarah only clicks on the red "Review Needed" flags to manually intervene.

## 2. The Student Flow (Leo)
**Goal:** Visually learn a concept without getting permanently stuck.
1. **Consumption:** Leo opens the Canvas via the link. He is presented with the interactive simulation.
2. **Interaction:** He plays with the variables (e.g., increasing magnet strength) and visually observes the field changes.
3. **The Socratic AI:** Leo is stuck on question 2. He selects his vector and clicks "Help".
4. **Context-Aware Prompt:** The system sends his exact vector coordinates and the curriculum rubric to the AI. The AI responds: "Notice the direction of the north pole. Which way do magnetic field lines travel?" (It does not give him the answer).
