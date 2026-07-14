/// Represents a chemical element in the periodic table.
class ChemicalElement {
  final int atomicNumber;
  final String symbol;
  final String name;
  final double atomicMass;
  final int group;
  final int period;
  final String category;
  final List<int> oxidationStates;
  final String electronConfiguration;

  const ChemicalElement({
    required this.atomicNumber,
    required this.symbol,
    required this.name,
    required this.atomicMass,
    required this.group,
    required this.period,
    required this.category,
    this.oxidationStates = const [],
    this.electronConfiguration = '',
  });
}
