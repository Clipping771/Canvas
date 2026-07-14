import 'package:vinci_board/engines/chemistry/core/element.dart';

/// Represents a chemical compound or ion.
class ChemicalCompound {
  final String formula;
  final String name;
  final double molarMass;
  final Map<ChemicalElement, int> composition;
  final int charge;
  final String state; // (s), (l), (g), (aq)

  const ChemicalCompound({
    required this.formula,
    required this.name,
    required this.molarMass,
    required this.composition,
    this.charge = 0,
    this.state = 'aq',
  });
}
