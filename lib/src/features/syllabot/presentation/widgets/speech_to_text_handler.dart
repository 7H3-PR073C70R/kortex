import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _isInitializing = false;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isAvailable;

  /// Initializes speech recognition engine and permissions.
  Future<bool> initialize() async {
    if (_isInitializing) return false;
    _isInitializing = true;
    try {
      try {
        final micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          final res = await Permission.microphone.request();
          if (!res.isGranted) {
            _isAvailable = false;
            _isInitializing = false;
            onError?.call(
              'Microphone permission required for speech recognition',
            );
            return false;
          }
        }
      } on Object catch (_) {
        // Continue if permission_handler is not configured for the target platform
      }

      _isAvailable = await _speechToText.initialize(
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
      _isInitializing = false;
      return _isAvailable;
    } on Object catch (e) {
      _isAvailable = false;
      _isInitializing = false;
      onError?.call('Speech recognition initialization error: $e');
      return false;
    }
  }

  /// Starts listening to microphone and transcribing speech.
  Future<void> startListening() async {
    if (_speechToText.isListening) {
      return;
    }

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call(
          'Microphone or Speech Recognition unavailable on this device',
        );
        return;
      }
    }

    try {
      unawaited(HapticFeedback.mediumImpact());
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      onListeningChanged(true);
    } on Object catch (e) {
      onListeningChanged(false);
      onError?.call('Speech recognition error: $e');
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
    try {
      await _speechToText.cancel();
      onListeningChanged(false);
    } on Object catch (_) {}
  }

  /// Releases resources.
  void dispose() {
    try {
      unawaited(_speechToText.cancel());
    } on Object catch (_) {}
  }
}
