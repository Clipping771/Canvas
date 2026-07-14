import 'package:vinci_board/engines/chemistry/lab/virtual_instrument.dart';
import 'package:vinci_board/engines/chemistry/lab/glassware.dart';

/// A Virtual pH Meter.
class PHMeter extends VirtualInstrument {
  double _calibrationOffset = 0.0;

  PHMeter({required super.id}) : super(name: "pH Meter");

  @override
  void calibrate() {
    _calibrationOffset = 0.01; // Mock calibration
  }

  @override
  double readMeasurement(dynamic target) {
    if (!isTurnedOn) return 0.0;
    if (target is Glassware) {
      return target.currentPh + _calibrationOffset;
    }
    return 7.0; // Default neutral if reading thin air
  }
}

/// A Virtual Analytical Balance.
class AnalyticalBalance extends VirtualInstrument {
  double _tareWeight = 0.0;

  AnalyticalBalance({required super.id}) : super(name: "Analytical Balance");

  @override
  void calibrate() {
    _tareWeight = 0.0; // Tare
  }

  /// Tares the scale (sets current weight to zero).
  void tare(double currentLoad) {
    _tareWeight = currentLoad;
  }

  @override
  double readMeasurement(dynamic target) {
    if (!isTurnedOn) return 0.0;
    if (target is Glassware) {
      return target.totalMass - _tareWeight;
    }
    return 0.0;
  }
}

/// A Virtual Thermometer.
class Thermometer extends VirtualInstrument {
  Thermometer({required super.id}) : super(name: "Thermometer");

  @override
  void calibrate() {}

  @override
  double readMeasurement(dynamic target) {
    if (target is Glassware) {
      return target.temperature;
    }
    return 298.15; // Room temp
  }
}
