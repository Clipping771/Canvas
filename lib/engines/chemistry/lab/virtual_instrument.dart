/// Base interface for all virtual chemistry instruments.
abstract class VirtualInstrument {
  final String id;
  final String name;
  bool isTurnedOn;

  VirtualInstrument({
    required this.id,
    required this.name,
    this.isTurnedOn = false,
  });

  /// Turns the instrument on or off.
  void togglePower() {
    isTurnedOn = !isTurnedOn;
  }

  /// Calibrates the instrument, if applicable.
  void calibrate();

  /// Gets the current reading from the instrument.
  /// Typically requires passing the container/glassware being measured.
  dynamic readMeasurement(dynamic target);
}
