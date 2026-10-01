import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Real-time speech recognition service for Syllabot AI voice input.
class SpeechToTextHandler {
  SpeechToTextHandler({
    required this.onResult,
    required this.onListeningChanged,
    this.onResultWithFinal,
    this.onError,
    this.onSoundLevelChange,
  });

  final ValueChanged<String> onResult;
  final void Function(String text, {required bool isFinal})? onResultWithFinal;
  final ValueChanged<bool> onListeningChanged;
  final ValueChanged<String>? onError;
  final ValueChanged<double>? onSoundLevelChange;

  final SpeechToText _speechToText = SpeechToText();
  bool _isAvailable = false;
  bool _isInitializing = false;
  bool _isStarting = false;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isAvailable;
  SpeechToText get rawInstance => _speechToText;

  /// Initializes speech recognition engine and permissions.
  Future<bool> initialize() async {
    if (_isAvailable) return true;
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

        final speechStatus = await Permission.speech.status;
        if (!speechStatus.isGranted) {
          final res = await Permission.speech.request();
          if (!res.isGranted) {
            _isAvailable = false;
            _isInitializing = false;
            onError?.call(
              'Speech recognition permission required for voice input',
            );
            return false;
          }
        }
      } on Object catch (_) {
        // Continue if permission_handler is not configured for the target platform
      }

      _isAvailable = await _speechToText.initialize(
        onError: (val) {
          // If error is normal silence timeout or no match, do not treat as fatal error
          final errorMsg = val.errorMsg.toLowerCase();
          if (errorMsg.contains('no_match') ||
              errorMsg.contains('timeout') ||
              errorMsg.contains('error_no_match') ||
              errorMsg.contains('error_speech_timeout')) {
            if (!_isStarting && !_isInitializing) {
              onListeningChanged(false);
            }
            return;
          }
          if (!_isStarting && !_isInitializing) {
            onListeningChanged(false);
          }
          onError?.call(val.errorMsg);
        },
        onStatus: (status) async {
          if (status == 'listening') {
            _isStarting = false;
            onListeningChanged(true);
          } else if (status == 'notListening' || status == 'done') {
            if (_isStarting || _isInitializing) return;
            // Delay by one microtask so the audio session fully closes
            // before the caller attempts a restart — avoids the isListening
            // race where startListening() sees isListening==true and bails.
            await Future<void>.microtask(() => onListeningChanged(false));
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
  Future<void> startListening({
    Duration listenFor = const Duration(minutes: 10),
    Duration pauseFor = const Duration(seconds: 30),
  }) async {
    if (_speechToText.isListening) {
      return;
    }

    _isStarting = true;

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        _isStarting = false;
        onError?.call(
          'Microphone or Speech Recognition unavailable on this device',
        );
        return;
      }
    }

    try {
      unawaited(HapticFeedback.mediumImpact());
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
            onResultWithFinal?.call(
              result.recognizedWords,
              isFinal: result.finalResult,
            );
          }
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
      // onStatus already fires onListeningChanged(true); no duplicate needed.
      _isStarting = false;
    } on Object catch (e) {
      _isStarting = false;
      onListeningChanged(false);
      onError?.call('Speech recognition error: $e');
    }
  }

  /// Stops speech listening session.
  Future<void> stopListening() async {
    _isStarting = false;
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
    _isStarting = false;
    try {
      await _speechToText.cancel();
      onListeningChanged(false);
    } on Object catch (_) {}
  }

  /// Releases resources.
  void dispose() {
    _isStarting = false;
    try {
      unawaited(_speechToText.cancel());
    } on Object catch (_) {}
  }
}
