/// Solves stoichiometry problems.
class StoichiometrySolver {
  /// Calculates the limiting reagent given a balanced equation and initial moles of reactants.
  /// reactantsMoles: Map of reactant formula to initial moles.
  /// coefficients: Map of reactant formula to its stoichiometric coefficient.
  /// Returns the formula of the limiting reagent.
  String findLimitingReagent(
    Map<String, double> reactantsMoles,
    Map<String, int> coefficients,
  ) {
    String limiting = '';
    double minRatio = double.infinity;

    reactantsMoles.forEach((formula, moles) {
      int coef = coefficients[formula] ?? 1;
      double ratio = moles / coef;
      if (ratio < minRatio) {
        minRatio = ratio;
        limiting = formula;
      }
    });

    return limiting;
  }

  /// Calculates the theoretical yield of a product given the moles of limiting reagent.
  double theoreticalYield(
    double limitingMoles,
    int limitingCoef,
    int productCoef,
    double productMolarMass,
  ) {
    return (limitingMoles / limitingCoef) * productCoef * productMolarMass;
  }
}
