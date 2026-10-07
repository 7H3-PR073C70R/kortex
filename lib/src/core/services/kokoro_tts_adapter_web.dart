import 'dart:typed_data';

class KokoroTtsAdapter {
  KokoroTtsAdapter();

  Future<void> initialize({
    void Function(double progress, String status)? onProgress,
    String? espeakDataPath,
  }) async {}

  Future<Float32List> generate(
    String text, {
    String voice = 'Default',
    double speed = 1.0,
  }) async =>
      Float32List(0);

  int get sampleRate => 24000;

  Future<void> dispose() async {}
}
