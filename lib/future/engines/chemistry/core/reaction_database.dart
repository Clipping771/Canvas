import 'package:vinci_board/engines/chemistry/core/reaction.dart';

/// Central database for known chemical reactions.
class ReactionDatabase {
  static final ReactionDatabase _instance = ReactionDatabase._internal();
  factory ReactionDatabase() => _instance;

  final Map<String, ChemicalReaction> _reactions = {};

  ReactionDatabase._internal() {
    _initializeReactions();
  }

  void _initializeReactions() {
    // We will populate this with named reactions and common inorganic reactions.
    // E.g., HCl + NaOH -> NaCl + H2O
  }

  ChemicalReaction? getReaction(String id) => _reactions[id];

  void addReaction(ChemicalReaction reaction) {
    _reactions[reaction.id] = reaction;
  }
}
