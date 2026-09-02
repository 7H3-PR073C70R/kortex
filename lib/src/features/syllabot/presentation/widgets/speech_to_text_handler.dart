import 'dart:async';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Real-time speech recognition service for Syllabot AI voice input.
class SpeechToTextHandler {
  SpeechToTextHandler({
    required this.onResult,
    required this.onListeningChanged,
    this.onError,
  });

  final ValueChanged<String> onResult;
  final ValueChanged<bool> onListeningChanged;
  final ValueChanged<String>? onError;

  final SpeechToText _speechToText = SpeechToText();
  bool _isAvailable = false;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isAvailable;

  /// Initializes speech recognition engine and permissions.
  Future<bool> initialize() async {
    try {
      return _isAvailable = await _speechToText.initialize(
        onError: (val) {
          onListeningChanged(false);
          onError?.call(val.errorMsg);
        },
        onStatus: (status) {
          if (status == 'listening') {
            onListeningChanged(true);
          } else if (status == 'notListening' || status == 'done') {
            onListeningChanged(false);
          }
        },
      );
    } on Object catch (e) {
      _isAvailable = false;
      onError?.call(e.toString());
      return false;
    }
  }

  /// Starts listening to microphone and transcribing speech.
  Future<void> startListening() async {
    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Microphone or Speech Recognition unavailable');
        return;
      }
    }

    try {
      unawaited(HapticFeedback.mediumImpact());
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      onListeningChanged(true);
    } on Object catch (e) {
      onListeningChanged(false);
      onError?.call(e.toString());
    }
  }

  /// Stops speech listening session.
  Future<void> stopListening() async {
    try {
      unawaited(HapticFeedback.lightImpact());
      await _speechToText.stop();
      onListeningChanged(false);
    } on Object catch (e) {
      onListeningChanged(false);
      onError?.call(e.toString());
    }
  }

  /// Cancels listening session.
  Future<void> cancel() async {
    await _speechToText.cancel();
    onListeningChanged(false);
  }

  /// Releases resources.
  void dispose() {
    unawaited(_speechToText.cancel());
  }
}
