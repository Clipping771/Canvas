import 'package:vinci_board/engines/chemistry/core/compound.dart';

/// Base class for all laboratory glassware containers.
abstract class Glassware {
  final String id;
  final String name;
  final double capacityVolume; // mL
  double currentVolume = 0.0;
  double temperature = 298.15; // Kelvin
  double totalMass = 0.0; // grams, including tare of glassware
  double currentPh = 7.0;

  final Map<ChemicalCompound, double> contents = {}; // Compound to moles

  Glassware({
    required this.id,
    required this.name,
    required this.capacityVolume,
    this.totalMass = 50.0, // Base weight of empty glass
  });

  /// Adds a compound to the glassware.
  void addCompound(
    ChemicalCompound compound,
    double moles,
    double volumeAdded,
    double massAdded,
  ) {
    contents[compound] = (contents[compound] ?? 0.0) + moles;
    currentVolume += volumeAdded;
    totalMass += massAdded;
    if (currentVolume > capacityVolume) {
      // Handle overflow
      currentVolume = capacityVolume;
    }
  }

  void clear() {
    contents.clear();
    currentVolume = 0.0;
    // totalMass resets to base empty mass in a full implementation
  }
}

class Beaker extends Glassware {
  Beaker({required super.id, double capacity = 250.0})
    : super(name: "Beaker", capacityVolume: capacity, totalMass: 100.0);
}

class Flask extends Glassware {
  Flask({required super.id, double capacity = 500.0})
    : super(
        name: "Erlenmeyer Flask",
        capacityVolume: capacity,
        totalMass: 150.0,
      );
}
