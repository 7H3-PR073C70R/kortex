import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Earcon tone types for Syllabot conversational state transitions.
enum EarconType {
  listeningStart,
  processingCommit,
  speakingStart,
  error,
}

/// Abstract contract for acoustic earcon sound effects during AI voice dialogue.
abstract class AudioEarconService {
  /// Plays a warm ascending chime when microphone activates for listening.
  Future<void> playListeningStart();

  /// Plays a soft dual-tone sweep when user prompt is committed for processing.
  Future<void> playProcessingCommit();

  /// Plays a crisp acoustic tone when AI voice response playback begins.
  Future<void> playSpeakingStart();

  /// Plays a low warning tone when an error occurs.
  Future<void> playError();

  /// Plays a specific earcon type directly.
  Future<void> playEarcon(EarconType type);

  /// Releases audio resources.
  void dispose();
}

/// Production implementation of [AudioEarconService] using in-memory procedural
/// RIFF/WAVE PCM synthesis for zero-dependency, ultra-fast earcon audio output.
class AudioEarconServiceImpl implements AudioEarconService {
  AudioEarconServiceImpl({AudioPlayer? audioPlayer})
      : _player = audioPlayer ?? AudioPlayer() {
    _initAudioPlayer();
  }

  final AudioPlayer _player;
  final Map<EarconType, String> _cachedToneFilePaths = {};
  bool _isDisposed = false;

  void _initAudioPlayer() {
    try {
      unawaited(_player.setVolume(0.45));
    } on Object catch (_) {}
  }

  @override
  Future<void> playListeningStart() => playEarcon(EarconType.listeningStart);

  @override
  Future<void> playProcessingCommit() => playEarcon(EarconType.processingCommit);

  @override
  Future<void> playSpeakingStart() => playEarcon(EarconType.speakingStart);

  @override
  Future<void> playError() => playEarcon(EarconType.error);

  @override
  Future<void> playEarcon(EarconType type) async {
    if (_isDisposed) return;

    // Trigger immediate synchronized haptic feedback for instant tactile response
    _triggerHapticForEarcon(type);

    try {
      final filePath = await _getOrCreateToneFile(type);
      if (filePath != null && filePath.isNotEmpty && !_isDisposed) {
        await _player.stop();
        await _player.play(DeviceFileSource(filePath));
      }
    } on Object catch (e) {
      debugPrint('AudioEarconService: Earcon playback fallback exception: $e');
    }
  }

  void _triggerHapticForEarcon(EarconType type) {
    try {
      switch (type) {
        case EarconType.listeningStart:
          unawaited(HapticFeedback.selectionClick());
        case EarconType.processingCommit:
          unawaited(HapticFeedback.mediumImpact());
        case EarconType.speakingStart:
          unawaited(HapticFeedback.lightImpact());
        case EarconType.error:
          unawaited(HapticFeedback.heavyImpact());
      }
    } on Object catch (_) {}
  }

  Future<String?> _getOrCreateToneFile(EarconType type) async {
    if (_cachedToneFilePaths.containsKey(type)) {
      final cachedPath = _cachedToneFilePaths[type]!;
      if (File(cachedPath).existsSync()) {
        return cachedPath;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/syllabot_earcon_${type.name}.wav');

      final bytes = _generateProceduralToneBytes(type);
      await file.writeAsBytes(bytes);
      _cachedToneFilePaths[type] = file.path;
      return file.path;
    } on Object catch (e) {
      debugPrint('AudioEarconService: Error building tone file: $e');
      return null;
    }
  }

  Uint8List _generateProceduralToneBytes(EarconType type) {
    const sampleRate = 22050;

    switch (type) {
      case EarconType.listeningStart:
        // Dual ascending chime: C5 (523.25 Hz, 70ms) -> G5 (783.99 Hz, 100ms)
        return _synthesizeSequenceWav(const [
          _ToneSegment(freqHz: 523.25, durationMs: 70, volume: 0.5),
          _ToneSegment(freqHz: 783.99, durationMs: 100, volume: 0.6),
        ], sampleRate: sampleRate);

      case EarconType.processingCommit:
        // Soft dual-tone sweep: E5 (659.25 Hz) -> A5 (880.00 Hz, 110ms)
        return _synthesizeSequenceWav(const [
          _ToneSegment(freqHz: 659.25, durationMs: 50, volume: 0.4),
          _ToneSegment(freqHz: 880, durationMs: 80, volume: 0.5),
        ], sampleRate: sampleRate);

      case EarconType.speakingStart:
        // Warm acoustic pop: G5 (783.99 Hz, 70ms)
        return _synthesizeSequenceWav(const [
          _ToneSegment(freqHz: 783.99, durationMs: 70, volume: 0.55),
        ], sampleRate: sampleRate);

      case EarconType.error:
        // Low warning tone: E4 (329.63 Hz, 80ms) -> C4 (261.63 Hz, 120ms)
        return _synthesizeSequenceWav(const [
          _ToneSegment(freqHz: 329.63, durationMs: 80, volume: 0.5),
          _ToneSegment(freqHz: 261.63, durationMs: 120, volume: 0.55),
        ], sampleRate: sampleRate);
    }
  }

  Uint8List _synthesizeSequenceWav(
    List<_ToneSegment> segments, {
    required int sampleRate,
  }) {
    final floatSamples = <double>[];

    for (final seg in segments) {
      final totalSamples = (sampleRate * (seg.durationMs / 1000.0)).round();
      final phaseIncrement = 2.0 * math.pi * seg.freqHz / sampleRate;

      for (var i = 0; i < totalSamples; i++) {
        final progress = i / totalSamples;
        // Apply smooth Sine attack and exponential decay envelope
        final envelope = math.sin(progress * math.pi) * math.exp(-progress * 2.5);
        final sample = math.sin(i * phaseIncrement) * seg.volume * envelope;
        floatSamples.add(sample);
      }
    }

    final pcm16Bytes = Uint8List(floatSamples.length * 2);
    for (var i = 0; i < floatSamples.length; i++) {
      var s = floatSamples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      final int16 = (s * 32767).round();
      pcm16Bytes[i * 2] = int16 & 0xff;
      pcm16Bytes[i * 2 + 1] = (int16 >> 8) & 0xff;
    }

    return _buildWavHeaderAndPayload(pcm16Bytes, sampleRate);
  }

  Uint8List _buildWavHeaderAndPayload(Uint8List pcm16Data, int sampleRate) {
    final dataLen = pcm16Data.length;
    const headerLen = 44;
    final out = Uint8List(headerLen + dataLen);
    var offset = 0;

    void add(List<int> bytes) {
      for (var i = 0; i < bytes.length; i++) {
        out[offset++] = bytes[i];
      }
    }

    add('RIFF'.codeUnits);
    add(_uint32ToBytes(headerLen - 8 + dataLen));
    add('WAVE'.codeUnits);
    add('fmt '.codeUnits);
    add(_uint32ToBytes(16));
    add(_uint16ToBytes(1)); // PCM format
    add(_uint16ToBytes(1)); // Mono
    add(_uint32ToBytes(sampleRate));
    add(_uint32ToBytes(sampleRate * 2));
    add(_uint16ToBytes(2));
    add(_uint16ToBytes(16));
    add('data'.codeUnits);
    add(_uint32ToBytes(dataLen));

    out.setRange(headerLen, headerLen + dataLen, pcm16Data);
    return out;
  }

  static List<int> _uint32ToBytes(int v) => [
        v & 0xff,
        (v >> 8) & 0xff,
        (v >> 16) & 0xff,
        (v >> 24) & 0xff,
      ];

  static List<int> _uint16ToBytes(int v) => [
        v & 0xff,
        (v >> 8) & 0xff,
      ];

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_player.dispose());
  }
}

class _ToneSegment {
  const _ToneSegment({
    required this.freqHz,
    required this.durationMs,
    required this.volume,
  });

  final double freqHz;
  final int durationMs;
  final double volume;
}
