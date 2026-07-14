/// Solves gas-related chemical laws.
class GasSolver {
  static const double rLAtm = 0.08206; // L*atm/(mol*K)
  static const double rJoules = 8.314; // J/(mol*K)

  /// Ideal Gas Law: PV = nRT. Solves for Pressure (atm)
  double calculatePressure({
    required double volume,
    required double moles,
    required double temperatureK,
  }) {
    if (volume <= 0) throw Exception("Volume must be greater than zero");
    return (moles * rLAtm * temperatureK) / volume;
  }

  /// Ideal Gas Law: PV = nRT. Solves for Volume (L)
  double calculateVolume({
    required double pressure,
    required double moles,
    required double temperatureK,
  }) {
    if (pressure <= 0) throw Exception("Pressure must be greater than zero");
    return (moles * rLAtm * temperatureK) / pressure;
  }
}
