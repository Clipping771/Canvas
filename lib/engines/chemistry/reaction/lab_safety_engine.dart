import 'package:vinci_board/engines/chemistry/core/compound.dart';
import 'package:vinci_board/engines/chemistry/reaction/reaction_conditions.dart';

/// Detects hazards, toxic gases, or explosive risks.
class LabSafetyEngine {
  /// Analyzes a set of reactants and conditions for safety hazards.
  /// Returns a list of warning strings.
  List<String> analyzeHazards(
    List<ChemicalCompound> reactants,
    ReactionConditions conditions,
  ) {
    List<String> warnings = [];

    bool hasSodium = reactants.any(
      (c) => c.formula == 'Na' || c.formula == 'K',
    );
    bool hasWater = reactants.any((c) => c.formula == 'H2O');

    if (hasSodium && hasWater) {
      warnings.add(
        '⚠️ EXPLOSION RISK: Alkali metal reacting violently with water.',
      );
    }

    bool hasSulfide = reactants.any(
      (c) => c.formula.contains('S') && c.charge < 0,
    );
    bool hasAcid = reactants.any(
      (c) => c.formula.startsWith('H') && c.formula != 'H2O',
    );

    if (hasSulfide && hasAcid) {
      warnings.add('⚠️ TOXIC GAS WARNING: Evolution of H2S gas.');
    }

    if (conditions.temperatureK > 500) {
      warnings.add('🔥 HIGH HEAT WARNING: Extreme temperature conditions.');
    }

    return warnings;
  }
}
