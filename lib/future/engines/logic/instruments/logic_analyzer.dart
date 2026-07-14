import 'package:vinci_board/engines/logic/models/circuit_pin.dart';

/// Tracks digital signal states over time for multiple channels.
class LogicAnalyzer {
  final int numberOfChannels;
  // Map of channel index to list of (time, boolean logic state)
  final Map<int, List<Map<double, bool>>> _timings = {};

  LogicAnalyzer({this.numberOfChannels = 8}) {
    for (int i = 0; i < numberOfChannels; i++) {
      _timings[i] = [];
    }
  }

  /// Records a snapshot of the digital state at a given time.
  void recordState(int channel, double timeSec, CircuitPin pin) {
    if (channel < 0 || channel >= numberOfChannels) return;

    // Assume high logic is V > 2.5V (standard 5V TTL)
    bool isHigh = pin.state.voltage > 2.5;
    _timings[channel]!.add({timeSec: isHigh});
  }

  /// Retrieves the waveform data for the UI to draw a digital timing diagram.
  List<Map<double, bool>> getWaveform(int channel) {
    return _timings[channel] ?? [];
  }
}
