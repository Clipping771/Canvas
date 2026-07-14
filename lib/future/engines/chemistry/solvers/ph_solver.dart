import 'dart:math' as math;

/// Solves pH related problems.
class PHSolver {
  /// Calculates pH given the concentration of H+ ions.
  double calculatePh(double hPlusConcentration) {
    if (hPlusConcentration <= 0) return 7.0;
    return -math.log(hPlusConcentration) / math.ln10;
  }

  /// Calculates pOH given the concentration of OH- ions.
  double calculatePoh(double ohMinusConcentration) {
    if (ohMinusConcentration <= 0) return 7.0;
    return -math.log(ohMinusConcentration) / math.ln10;
  }

  /// Calculates pH of a buffer solution using the Henderson-Hasselbalch equation.
  double hendersonHasselbalch(
    double pKa,
    double saltConcentration,
    double acidConcentration,
  ) {
    if (acidConcentration <= 0) return pKa;
    return pKa + (math.log(saltConcentration / acidConcentration) / math.ln10);
  }
}
