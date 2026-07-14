import 'package:vinci_board/engines/chemistry/core/compound.dart';

/// Represents a single chemical reaction.
class ChemicalReaction {
  final String id;
  final String name;
  final Map<ChemicalCompound, int> reactants;
  final Map<ChemicalCompound, int> products;
  final String type; // e.g., 'acid-base', 'redox', 'precipitation'
  final bool isReversible;

  const ChemicalReaction({
    required this.id,
    required this.name,
    required this.reactants,
    required this.products,
    this.type = 'general',
    this.isReversible = false,
  });
}
