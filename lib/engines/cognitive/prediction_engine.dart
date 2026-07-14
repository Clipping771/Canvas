import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vinci_board/engines/cognitive/task_scheduler.dart';
import 'package:vinci_board/engines/cognitive/spatial_memory.dart';
import 'package:vinci_board/engines/cognitive/attention_engine.dart';

enum PredictionTriggerEvent {
  pause,
  zoom,
  lassoSelection,
  repeatedStroke,
  rapidSketch,
}

class PredictionEngine implements CognitiveSubsystem {
  final SpatialMemory spatialMemory;
  final AttentionEngine attentionEngine;

  final ValueNotifier<String?> ghostPrediction = ValueNotifier(null);

  // Track last events to debounce and prevent over-triggering API
  DateTime _lastTriggerTime = DateTime.now();
  Timer? _debounceTimer;

  PredictionEngine(this.spatialMemory, this.attentionEngine);

  void triggerEvent(PredictionTriggerEvent event) {
    if (DateTime.now().difference(_lastTriggerTime) <
        const Duration(seconds: 2)) {
      return; // Debounce to save tokens
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _runPrediction(event);
    });
  }

  Future<void> _runPrediction(PredictionTriggerEvent event) async {
    _lastTriggerTime = DateTime.now();
    // Simulate API call to prediction model based on spatial memory
    ghostPrediction.value = "Analyzing intent from ${event.name}...";

    await Future.delayed(const Duration(seconds: 1));

    // In production, this would use a fast, localized AI model or API call
    switch (event) {
      case PredictionTriggerEvent.lassoSelection:
        ghostPrediction.value = "Group these items?";
        break;
      case PredictionTriggerEvent.rapidSketch:
        ghostPrediction.value = "Draw a perfect circle?";
        break;
      case PredictionTriggerEvent.repeatedStroke:
        ghostPrediction.value = "Hatching/Shading pattern?";
        break;
      default:
        ghostPrediction.value = null; // Clear if no clear prediction
    }

    // Clear prediction after a while if not acted upon
    Future.delayed(const Duration(seconds: 3), () {
      if (ghostPrediction.value != null) {
        ghostPrediction.value = null;
      }
    });
  }

  @override
  TaskPriority get priority => TaskPriority.low; // Background prediction

  @override
  bool get isActive => true;

  @override
  void onTick(Duration elapsed) {
    // We don't poll here anymore. This is strictly event-driven.
  }
}
