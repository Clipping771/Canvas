import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/engines/chemistry/core/compound_database.dart';
import 'package:vinci_board/engines/chemistry/reaction/chemical_equation_execution_engine.dart';
import 'package:vinci_board/engines/chemistry/reaction/reaction_conditions.dart';

final chemistryDatabaseProvider = Provider<CompoundDatabase>((ref) {
  return CompoundDatabase();
});

final chemistryEngineProvider = Provider<ChemicalEquationExecutionEngine>((ref) {
  return ChemicalEquationExecutionEngine();
});

final reactionConditionsProvider = Provider<ReactionConditions>((ref) {
  return ReactionConditions(temperatureK: 298.15, pressureAtm: 1.0);
});
