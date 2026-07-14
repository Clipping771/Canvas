/// A snapshot of the experiment state at a given time.
class ExperimentSnapshot {
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> stateData;

  ExperimentSnapshot({
    required this.timestamp,
    required this.description,
    required this.stateData,
  });
}

/// Records snapshots and timeline of an ongoing virtual experiment.
class ExperimentRecorder {
  final List<ExperimentSnapshot> _timeline = [];

  void recordState(String description, Map<String, dynamic> stateData) {
    _timeline.add(
      ExperimentSnapshot(
        timestamp: DateTime.now(),
        description: description,
        stateData: Map.from(stateData), // deep copy in a real app
      ),
    );
  }

  List<ExperimentSnapshot> get timeline => _timeline;

  /// Reverts the lab to a previous snapshot state.
  void undoTo(int index) {
    if (index >= 0 && index < _timeline.length) {
      // Revert logic here
      _timeline.removeRange(index + 1, _timeline.length);
    }
  }

  void clear() {
    _timeline.clear();
  }
}
