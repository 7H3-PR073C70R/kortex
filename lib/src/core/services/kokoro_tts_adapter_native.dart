import 'dart:typed_data';

import 'package:flutter_kokoro_tts/flutter_kokoro_tts.dart';

class KokoroTtsAdapter {
  KokoroTtsAdapter() : _kokoroTts = KokoroTts();
  final KokoroTts _kokoroTts;

  Future<void> initialize({
    void Function(double progress, String status)? onProgress,
    String? espeakDataPath,
  }) =>
      _kokoroTts.initialize(
        onProgress: onProgress,
        espeakDataPath: espeakDataPath,
      );

  Future<Float32List> generate(
    String text, {
    String voice = 'Default',
    double speed = 1.0,
  }) =>
      _kokoroTts.generate(text, voice: voice, speed: speed);

  int get sampleRate => 24000;

  Future<void> dispose() => _kokoroTts.dispose();
}
