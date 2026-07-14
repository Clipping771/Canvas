/// Solves thermodynamic equations.
class ThermodynamicsSolver {
  /// Calculates Gibbs Free Energy change: ΔG = ΔH - TΔS
  /// deltaH: Enthalpy change in kJ/mol
  /// temperatureK: Temperature in Kelvin
  /// deltaS: Entropy change in J/(mol*K)
  /// Returns ΔG in kJ/mol
  double calculateGibbsFreeEnergy(
    double deltaH,
    double temperatureK,
    double deltaS,
  ) {
    // Convert deltaS to kJ/(mol*K)
    double deltasKj = deltaS / 1000.0;
    return deltaH - (temperatureK * deltasKj);
  }

  /// Determines if a reaction is spontaneous at a given temperature.
  bool isSpontaneous(double deltaH, double temperatureK, double deltaS) {
    return calculateGibbsFreeEnergy(deltaH, temperatureK, deltaS) < 0;
  }
}
