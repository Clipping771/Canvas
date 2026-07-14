import 'dart:math' as math;
import 'package:vinci_board/engines/chemistry/core/compound.dart';

/// Calculates the molar mass of a given compound using the database.
class MolarMassCalculator {
  double calculate(ChemicalCompound compound) {
    double mass = 0.0;
    compound.composition.forEach((element, count) {
      mass += element.atomicMass * count;
    });
    return mass;
  }
}

/// Calculates solution concentrations (Molarity, Molality).
class SolutionConcentrationCalculator {
  /// Molarity = moles of solute / liters of solution
  double calculateMolarity(double molesOfSolute, double litersOfSolution) {
    if (litersOfSolution <= 0) return 0.0;
    return molesOfSolute / litersOfSolution;
  }

  /// Molality = moles of solute / kg of solvent
  double calculateMolality(double molesOfSolute, double kgOfSolvent) {
    if (kgOfSolvent <= 0) return 0.0;
    return molesOfSolute / kgOfSolvent;
  }
}

/// Solves electrochemical cell potential using the Nernst Equation.
/// E = E0 - (RT/nF) * ln(Q)
class NernstEquationCalculator {
  static const double R = 8.314; // J/(mol*K)
  static const double F = 96485; // C/mol (Faraday's constant)

  double calculateCellPotential({
    required double standardPotentialE0,
    required double temperatureK,
    required int electronsTransferredN,
    required double reactionQuotientQ,
  }) {
    if (electronsTransferredN == 0 || reactionQuotientQ <= 0) {
      return standardPotentialE0;
    }

    double term = (R * temperatureK) / (electronsTransferredN * F);
    return standardPotentialE0 - (term * math.log(reactionQuotientQ));
  }
}
