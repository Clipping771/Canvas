/// Defines the physical and chemical conditions for a reaction.
class ReactionConditions {
  final double temperatureK;
  final double pressureAtm;
  final String? solvent;
  final String? catalyst;
  final double? ph;
  final bool hasLight;

  const ReactionConditions({
    this.temperatureK = 298.15, // Standard room temp ~25C
    this.pressureAtm = 1.0,
    this.solvent = 'H2O',
    this.catalyst,
    this.ph,
    this.hasLight = false,
  });
}
