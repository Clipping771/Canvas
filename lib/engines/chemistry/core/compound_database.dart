import 'package:vinci_board/engines/chemistry/core/element.dart';
import 'package:vinci_board/engines/chemistry/core/compound.dart';

/// Database for elements, common compounds, and functional groups.
class CompoundDatabase {
  static final CompoundDatabase _instance = CompoundDatabase._internal();
  factory CompoundDatabase() => _instance;

  final Map<String, ChemicalElement> _elements = {};
  final Map<String, ChemicalCompound> _compounds = {};

  CompoundDatabase._internal() {
    _initializeElements();
    _initializeCommonCompounds();
  }

  void _initializeElements() {
    // A subset of elements for testing
    _elements['H'] = const ChemicalElement(
      atomicNumber: 1,
      symbol: 'H',
      name: 'Hydrogen',
      atomicMass: 1.008,
      group: 1,
      period: 1,
      category: 'nonmetal',
      oxidationStates: [1, -1],
    );
    _elements['O'] = const ChemicalElement(
      atomicNumber: 8,
      symbol: 'O',
      name: 'Oxygen',
      atomicMass: 15.999,
      group: 16,
      period: 2,
      category: 'nonmetal',
      oxidationStates: [-2, -1],
    );
    _elements['Na'] = const ChemicalElement(
      atomicNumber: 11,
      symbol: 'Na',
      name: 'Sodium',
      atomicMass: 22.990,
      group: 1,
      period: 3,
      category: 'alkali metal',
      oxidationStates: [1],
    );
    _elements['Cl'] = const ChemicalElement(
      atomicNumber: 17,
      symbol: 'Cl',
      name: 'Chlorine',
      atomicMass: 35.45,
      group: 17,
      period: 3,
      category: 'halogen',
      oxidationStates: [-1, 1, 3, 5, 7],
    );
    _elements['C'] = const ChemicalElement(
      atomicNumber: 6,
      symbol: 'C',
      name: 'Carbon',
      atomicMass: 12.011,
      group: 14,
      period: 2,
      category: 'nonmetal',
      oxidationStates: [-4, -3, -2, -1, 1, 2, 3, 4],
    );
  }

  void _initializeCommonCompounds() {
    // Water
    _compounds['H2O'] = ChemicalCompound(
      formula: 'H2O',
      name: 'Water',
      molarMass: 18.015,
      composition: {_elements['H']!: 2, _elements['O']!: 1},
      state: 'l',
    );
    // Sodium Chloride
    _compounds['NaCl'] = ChemicalCompound(
      formula: 'NaCl',
      name: 'Sodium Chloride',
      molarMass: 58.44,
      composition: {_elements['Na']!: 1, _elements['Cl']!: 1},
      state: 's',
    );
  }

  ChemicalElement? getElement(String symbol) => _elements[symbol];
  ChemicalCompound? getCompound(String formula) => _compounds[formula];

  /// Dynamically create a compound if not in DB
  void addCompound(ChemicalCompound compound) {
    _compounds[compound.formula] = compound;
  }
}
