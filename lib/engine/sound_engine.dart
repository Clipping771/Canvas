import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class SoundEngine {
  static final SoundEngine instance = SoundEngine._init();
  late AudioPlayer _player;
  String? _beepPath;
  bool _isReady = false;

  SoundEngine._init() {
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);
    _setupAudio();
  }

  Future<void> _setupAudio() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/draw_tone.wav');

    if (!await file.exists()) {
      int sampleRate = 44100;
      int numSamples = sampleRate * 10; // 10 seconds continuous tone

      var builder = BytesBuilder();
      builder.add('RIFF'.codeUnits);

      var sizeBytes = ByteData(4)
        ..setUint32(0, 36 + numSamples * 2, Endian.little);
      builder.add(sizeBytes.buffer.asUint8List());

      builder.add('WAVE'.codeUnits);
      builder.add('fmt '.codeUnits);

      var fmtSize = ByteData(4)..setUint32(0, 16, Endian.little);
      builder.add(fmtSize.buffer.asUint8List());

      var audioFormat = ByteData(2)..setUint16(0, 1, Endian.little);
      builder.add(audioFormat.buffer.asUint8List());

      var numChannels = ByteData(2)..setUint16(0, 1, Endian.little);
      builder.add(numChannels.buffer.asUint8List());

      var sampleRateData = ByteData(4)..setUint32(0, sampleRate, Endian.little);
      builder.add(sampleRateData.buffer.asUint8List());

      var byteRate = ByteData(4)..setUint32(0, sampleRate * 2, Endian.little);
      builder.add(byteRate.buffer.asUint8List());

      var blockAlign = ByteData(2)..setUint16(0, 2, Endian.little);
      builder.add(blockAlign.buffer.asUint8List());

      var bitsPerSample = ByteData(2)..setUint16(0, 16, Endian.little);
      builder.add(bitsPerSample.buffer.asUint8List());

      builder.add('data'.codeUnits);

      var dataSize = ByteData(4)..setUint32(0, numSamples * 2, Endian.little);
      builder.add(dataSize.buffer.asUint8List());

      for (int i = 0; i < numSamples; i++) {
        double t = i / sampleRate;
        // Warm saw/sine blend at low frequency
        double val = sin(2 * pi * 150 * t) * 0.7 + sin(2 * pi * 300 * t) * 0.3;
        int sample = (val * 8000).toInt(); // Low volume
        var sampleBytes = ByteData(2)..setInt16(0, sample, Endian.little);
        builder.add(sampleBytes.buffer.asUint8List());
      }

      await file.writeAsBytes(builder.toBytes());
    }

    _beepPath = file.path;
    await _player.setSourceDeviceFile(_beepPath!);
    _isReady = true;
  }

  void startDrawing() {
    if (!_isReady) return;
    _player.resume();
    _player.setPlaybackRate(1.0);
  }

  void updateDrawingSpeed(double speed) {
    if (!_isReady) return;
    // Map speed (pixels per frame approx) to pitch multiplier 0.5 to 2.0
    double rate = 0.5 + (speed / 20.0).clamp(0.0, 1.5);
    _player.setPlaybackRate(rate);
  }

  void stopDrawing() {
    if (!_isReady) return;
    _player.pause();
  }
}
