import 'package:vinci_board/engines/chemistry/core/compound.dart';

/// Represents a bottle of chemical reagent in the inventory.
class ReagentBottle {
  final ChemicalCompound compound;
  final double initialVolume;
  double currentVolume;
  final DateTime expiryDate;

  ReagentBottle({
    required this.compound,
    required this.initialVolume,
    required this.expiryDate,
  }) : currentVolume = initialVolume;
}

/// Tracks all available chemicals in the virtual laboratory.
class ReagentInventorySystem {
  final Map<String, ReagentBottle> _inventory = {};

  void stockReagent(
    String id,
    ChemicalCompound compound,
    double volume,
    DateTime expiry,
  ) {
    _inventory[id] = ReagentBottle(
      compound: compound,
      initialVolume: volume,
      expiryDate: expiry,
    );
  }

  ReagentBottle? getReagent(String id) => _inventory[id];

  /// Dispenses a specified volume of reagent.
  /// Returns the actual volume dispensed (might be less if not enough stock).
  double dispense(String id, double requestVolume) {
    var bottle = _inventory[id];
    if (bottle == null) return 0.0;

    if (bottle.currentVolume >= requestVolume) {
      bottle.currentVolume -= requestVolume;
      return requestVolume;
    } else {
      double available = bottle.currentVolume;
      bottle.currentVolume = 0;
      return available;
    }
  }
}
