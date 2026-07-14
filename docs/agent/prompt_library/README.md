# Prompt Library

This directory holds the baseline LLM prompts used by the `IAiProviderPort` adapters. 

> **CRITICAL RULE:** Because LLMs are non-deterministic, you cannot change a prompt in this directory without running the regression test suite (`spikes/ai_grading_prototype.dart`) against the 50 baseline exam papers.

## Why store prompts as Markdown?
Storing prompts here instead of hardcoding them inside Dart strings allows:
1. Version control of prompt engineering.
2. Easy review by the human Product Owner (Teachers).
3. The ability to load them dynamically via the `StoragePort`.

---

## Example: `grading_rubric_v1.md`

**System Instructions:**
You are an expert high school STEM teacher. You are evaluating a student's answer based on a specific rubric.
You must return your response STRICTLY as a JSON object matching this schema:
```json
{
  "score": int (0-10),
  "feedback": "string",
  "confidence": double (0.0 - 1.0),
  "flagForHumanReview": boolean
}
```

**Evaluation Rules:**
1. If you are less than 90% confident, you MUST set `flagForHumanReview` to true.
2. Do not penalize for minor spelling mistakes unless it changes the scientific meaning.
3. Your feedback must follow the Socratic method (do not just give the correct answer; explain what they missed).
