import 'package:vinci_board/engines/chemistry/core/compound_database.dart';

/// Wraps logic for the Interactive Periodic Table.
class InteractivePeriodicTable {
  final CompoundDatabase _db = CompoundDatabase();

  /// Gets element properties formatted for UI display.
  Map<String, dynamic> getElementDetails(String symbol) {
    final element = _db.getElement(symbol);
    if (element == null) return {"error": "Element not found"};

    return {
      "name": element.name,
      "symbol": element.symbol,
      "atomicNumber": element.atomicNumber,
      "atomicMass": element.atomicMass,
      "group": element.group,
      "period": element.period,
      "category": element.category,
      "oxidationStates": element.oxidationStates,
    };
  }
}

/// Core logic for Formula Explorer
class FormulaExplorer {
  final CompoundDatabase _db = CompoundDatabase();

  /// Generates a comprehensive breakdown for a given formula string.
  Map<String, dynamic> exploreFormula(String formula) {
    final compound = _db.getCompound(formula);
    if (compound == null) {
      return {
        "error":
            "Compound not found in local database. Requires PubChem fetch.",
      };
    }

    return {
      "name": compound.name,
      "formula": compound.formula,
      "molarMass": compound.molarMass,
      "state": compound.state,
      "elements": compound.composition.keys.map((e) => e.symbol).toList(),
      // In full implementation, this would link to derivations, graphs, and simulation hooks.
      "hasSimulationAvailable": true,
    };
  }
}
