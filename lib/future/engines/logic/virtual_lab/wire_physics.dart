/// Models physical limits of connecting wires.
class WirePhysics {
  // A standard 22 AWG hookup wire used in breadboards.
  static const double resistancePerMeter = 0.053; // Ohms
  static const double maxCurrentCapacity = 7.0; // Amps (safe limit)

  /// Calculates the resistance of a wire given its physical length on the canvas.
  double calculateResistance(double lengthMeters) {
    return lengthMeters * resistancePerMeter;
  }

  /// Checks if the current passing through the wire exceeds its safe limit, causing burnout.
  bool isBurnout(double currentAmps) {
    return currentAmps.abs() > maxCurrentCapacity;
  }
}
