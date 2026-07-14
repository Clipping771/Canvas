import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  /// Initializes the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speechToText.initialize(
      onError: (val) => debugPrint('Speech Error: ${val.errorMsg}'),
      onStatus: (val) => debugPrint('Speech Status: $val'),
    );
    return _isInitialized;
  }

  /// Starts listening to voice input and calls [onResult] with the transcription
  Future<void> startListening(Function(String) onResult) async {
    if (!_isInitialized) {
      bool ready = await initialize();
      if (!ready) return;
    }
    await _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// Stops the current listening session
  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  bool get isListening => _speechToText.isListening;
}
