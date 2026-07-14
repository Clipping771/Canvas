# 05 - Curriculum Architecture

> **The Golden Rule:** Stable Core. Replaceable Everything Else.

The biggest mistake in EdTech is hardcoding the US Common Core or Australian Curriculum into the application logic. Vinci Board utilizes a deeply hierarchical configuration system.

## 1. The Configuration Hierarchy
Settings cascade downwards. If a setting is not explicitly defined at a lower level, it falls back to the parent.
`Platform Defaults -> Country (Adapter) -> State/Province -> School -> Teacher -> Student`

## 2. The Curriculum Adapter
The Core Platform only understands generic terms: `Subject`, `Strand`, `Topic`, `Lesson`.
To load the Australian Year 11 Physics curriculum, the system injects an `ICurriculumAdapter`.

### Adapter Responsibilities:
- Fetch JSON/YAML definitions of the local curriculum.
- Map local curriculum IDs to Vinci Board `Topic` IDs.
- Determine which `Engines` should be loaded for a specific subject (e.g., Load `PhysicsSimulatorEngine` when the `Mechanics` topic is active).

## 3. The Subject Registry (YAML Spec)
Subjects are defined in YAML and loaded dynamically.

```yaml
SubjectPlugin:
  Id: aus_physics_y11
  Name: Year 11 Physics (ACARA)
  RequiredEngines:
    - VectorMathEngine
    - KinematicsSimulator
  BlockedEngines:
    - OrganicChemistryEngine # Don't load unused engines to save memory
```
