/// Defines the states of cellular division
enum CellDivisionPhase {
  interphase,
  prophase,
  metaphase,
  anaphase,
  telophase,
  cytokinesis,
}

/// Simulates cellular processes and organelle functions.
class CellularSimulator {
  CellDivisionPhase currentPhase = CellDivisionPhase.interphase;

  /// Simulates advancing the cell cycle one step forward.
  CellDivisionPhase advanceCellCycle() {
    switch (currentPhase) {
      case CellDivisionPhase.interphase:
        currentPhase = CellDivisionPhase.prophase;
        break;
      case CellDivisionPhase.prophase:
        currentPhase = CellDivisionPhase.metaphase;
        break;
      case CellDivisionPhase.metaphase:
        currentPhase = CellDivisionPhase.anaphase;
        break;
      case CellDivisionPhase.anaphase:
        currentPhase = CellDivisionPhase.telophase;
        break;
      case CellDivisionPhase.telophase:
        currentPhase = CellDivisionPhase.cytokinesis;
        break;
      case CellDivisionPhase.cytokinesis:
        // Resets back to interphase for the two new daughter cells
        currentPhase = CellDivisionPhase.interphase;
        break;
    }
    return currentPhase;
  }

  /// Calculates ATP production based on glucose and oxygen availability
  /// Uses a simplified model of cellular respiration (1 Glucose + 6 O2 -> 38 ATP)
  int calculateATPProduction(int glucoseMolecules, int oxygenMolecules) {
    // Requires 6 oxygen per glucose for aerobic respiration
    int maxAerobic = (oxygenMolecules / 6).floor();
    int actualAerobic = glucoseMolecules < maxAerobic
        ? glucoseMolecules
        : maxAerobic;

    // Remaining glucose undergoes anaerobic respiration (fermentation) yielding 2 ATP
    int remainingGlucose = glucoseMolecules - actualAerobic;

    return (actualAerobic * 38) + (remainingGlucose * 2);
  }
}
