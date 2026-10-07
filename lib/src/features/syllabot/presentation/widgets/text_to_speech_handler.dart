import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/text_to_speech_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/tts_config.dart';

export 'package:kortex/src/core/services/text_to_speech_service.dart'
    show TextToSpeechService, TtsEngineType;
export 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
export 'package:kortex/src/features/syllabot/presentation/widgets/tts_config.dart';

/// Adapter and presentation-layer facade for the centralized [TextToSpeechService].
///
/// Routes all speech synthesis through Kortex's 3-tier speech pipeline:
/// 1. Microsoft Edge Online Neural TTS (when internet is available).
/// 2. Kokoro ONNX On-Device Neural TTS (24 kHz offline synthesis).
/// 3. Platform native Speech Synthesizer fallback in case of exception.
class TextToSpeechHandler {
  TextToSpeechHandler({
    this.onSpeakingChanged,
    this.onError,
    LocalStorageService? localStorageService,
    TextToSpeechService? ttsService,
  }) : _service = ttsService ??
            (locator.isRegistered<TextToSpeechService>()
                ? locator<TextToSpeechService>()
                : TextToSpeechServiceImpl(
                    localStorageService: localStorageService ??
                        (locator.isRegistered<LocalStorageService>()
                            ? locator<LocalStorageService>()
                            : null),
                    onError: onError,
                    onSpeakingChanged: onSpeakingChanged,
                  )) {
    _isSpeakingListener = () {
      if (_isDisposed) return;
      final speaking = _service.isSpeaking;
      try {
        if (isSpeakingNotifier.value != speaking) {
          isSpeakingNotifier.value = speaking;
          onSpeakingChanged?.call(speaking);
        }
      } on Object catch (_) {}
    };
    _service.isSpeakingNotifier.addListener(_isSpeakingListener);
    isSpeakingNotifier.value = _service.isSpeaking;
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  final ValueChanged<bool>? onSpeakingChanged;
  final ValueChanged<String>? onError;
  final TextToSpeechService _service;
  late final VoidCallback _isSpeakingListener;

  /// Reactive notifier for UI widgets (e.g. Chat Input Bar mic lock-out).
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  TextToSpeechService get service => _service;
  bool get isSpeaking => _service.isSpeaking;
  VoiceGender get voiceGender => _service.voiceGender;
  double get speechRate => _service.speechRate;
  double get speechPitch => _service.speechPitch;
  String? get customVoiceName => _service.kokoroVoice;
  TtsEngineType get lastEngineUsed => _service.lastEngineUsed;
  List<String> get availableKokoroVoices => _service.availableKokoroVoices;

  ValueNotifier<double> get kokoroDownloadProgressNotifier =>
      _service.kokoroDownloadProgressNotifier;
  ValueNotifier<bool> get isKokoroModelReadyNotifier =>
      _service.isKokoroModelReadyNotifier;
  ValueNotifier<String> get kokoroDownloadStatusNotifier =>
      _service.kokoroDownloadStatusNotifier;
  ValueNotifier<bool> get isKokoroDownloadingNotifier =>
      _service.isKokoroDownloadingNotifier;

  Future<void> startKokoroModelDownload() =>
      _service.startKokoroModelDownload();

  TtsConfig get config => TtsConfig.forCurrentPlatform(
        gender: _service.voiceGender,
        speechRateMultiplier: _service.speechRate,
        pitch: _service.speechPitch,
      );

  bool get hasQueuedSentences => _service.isSpeaking;

  Future<void> setVoiceGender(VoiceGender gender) =>
      _service.setVoiceGender(gender);

  Future<void> setSpeechRate(double rate) => _service.setSpeechRate(rate);

  Future<void> setVoicePitch(double pitch) => _service.setSpeechPitch(pitch);

  Future<void> setVoiceName(String? voiceName) =>
      _service.setVoiceName(voiceName);

  Future<void> setKokoroVoice(String voiceName) =>
      _service.setKokoroVoice(voiceName);

  Future<void> setEdgeVoice(String voiceName) =>
      _service.setEdgeVoice(voiceName);

  /// Retrieves available voices across Kokoro on-device and system engines.
  Future<List<Map<String, dynamic>>> getAvailableVoices() =>
      _service.getAvailableVoices();

  // ---------------------------------------------------------------------------
  // Backward-compatible Text Preprocessing Delegates
  // ---------------------------------------------------------------------------

  /// Normalizes markdown, LaTeX, acronyms, and formatting for speech.
  static String cleanTextForSpeech(String markdown) =>
      SpeechTextNormalizer.normalize(markdown);

  /// Splits normalized text into natural speech chunks.
  static List<String> splitIntoChunks(String text) =>
      SpeechTextNormalizer.splitIntoChunks(text);

  // ---------------------------------------------------------------------------
  // Public Control API
  // ---------------------------------------------------------------------------

  /// Enqueues a single sentence for sequential synthesis.
  Future<void> enqueueSentence(String rawSentence) =>
      _service.enqueueSentence(rawSentence);

  /// Synthesizes speech for [rawText], clearing any prior queued speech.
  Future<void> speak(String rawText) => _service.speak(rawText);

  /// Clears any pending speech in the queue without interrupting active playback.
  void clearQueue() => _service.clearQueue();

  /// Waits until all queued sentences have completed synthesis and playback.
  Future<void> waitForQueueDrained() => _service.waitForQueueDrained();

  /// Immediately interrupts ongoing speech, flushes queue, and updates state.
  Future<void> stop() => _service.stop();

  /// Releases resources and detaches listener.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _service.isSpeakingNotifier.removeListener(_isSpeakingListener);
    isSpeakingNotifier.dispose();
  }
}
