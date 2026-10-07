import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

export 'package:speech_to_text/speech_to_text.dart' show ListenMode;

/// Real-time speech recognition service for Syllabot AI voice input.
class SpeechToTextHandler {
  SpeechToTextHandler({
    required this.onResult,
    required this.onListeningChanged,
    this.onResultWithFinal,
    this.onError,
    this.onSoundLevelChange,
    SpeechToText? speechToText,
  }) : _speechToText = speechToText ?? SpeechToText();

  final ValueChanged<String> onResult;
  final void Function(String text, {required bool isFinal})? onResultWithFinal;
  final ValueChanged<bool> onListeningChanged;
  final ValueChanged<String>? onError;
  final ValueChanged<double>? onSoundLevelChange;

  final SpeechToText _speechToText;
  bool _isAvailable = false;
  Completer<bool>? _initCompleter;

  static const Duration _windowsMinPauseFor = Duration(seconds: 6);

  /// Message shown when voice input is attempted on an unsupported platform.
  static const String unsupportedPlatformMessage =
      "Voice input isn't supported on Linux yet.";

  /// Whether the `speech_to_text` plugin has a native implementation for the
  /// current platform. It has none for Linux, so mic entry points should be
  /// hidden there.
  static bool get isPlatformSupported => kIsWeb || !Platform.isLinux;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isAvailable;
  SpeechToText get rawInstance => _speechToText;

  /// Initializes speech recognition engine and permissions.
  Future<bool> initialize() async {
    if (_isAvailable) return true;
    if (!isPlatformSupported) {
      onError?.call(unsupportedPlatformMessage);
      return false;
    }
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    final completer = Completer<bool>();
    _initCompleter = completer;

    try {
      try {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) {
            final res = await Permission.microphone.request();
            if (res.isPermanentlyDenied) {
              _isAvailable = false;
              completer.complete(false);
              onError?.call(
                'Microphone permission is required. Please enable it in Settings.',
              );
              return false;
            }
          }

          if (Platform.isIOS) {
            final speechStatus = await Permission.speech.status;
            if (!speechStatus.isGranted) {
              await Permission.speech.request();
            }
          }
        }
      } on Object catch (_) {
        // Continue if permission_handler is not configured for the target platform;
        // _speechToText.initialize() will handle native permission requests internally.
      }

      _isAvailable = await _speechToText.initialize(
        debugLogging: kDebugMode,
        onError: (val) {
          // If error is normal silence timeout or no match, do not treat as fatal error
          final errorMsg = val.errorMsg.toLowerCase();
          if (errorMsg.contains('no_match') ||
              errorMsg.contains('timeout') ||
              errorMsg.contains('error_no_match') ||
              errorMsg.contains('error_speech_timeout')) {
            onListeningChanged(false);
            return;
          }
          onListeningChanged(false);
          onError?.call(val.errorMsg);
        },
        onStatus: (status) async {
          if (status == 'listening') {
            onListeningChanged(true);
          } else if (status == 'notListening' || status == 'done') {
            // Delay by one microtask so the audio session fully closes
            // before the caller attempts a restart.
            await Future<void>.microtask(() => onListeningChanged(false));
          }
        },
      );

      if (!_isAvailable) {
        if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
          final micStatus = await Permission.microphone.status;
          if (micStatus.isPermanentlyDenied || micStatus.isDenied) {
            onError?.call(
              'Microphone permission is required. Please enable it in Settings.',
            );
          } else if (Platform.isIOS) {
            final speechStatus = await Permission.speech.status;
            if (speechStatus.isPermanentlyDenied || speechStatus.isDenied) {
              onError?.call(
                'Speech recognition permission is required. Please enable it in Settings.',
              );
            } else {
              onError?.call(
                'Speech recognition is unavailable on this device.',
              );
            }
          } else {
            onError?.call(
              'Speech recognition is unavailable on this device.',
            );
          }
        } else if (!kIsWeb && Platform.isMacOS) {
          onError?.call(
            'Speech recognition is unavailable or not permitted. Please check System Settings > Privacy & Security > Speech Recognition & Microphone.',
          );
        } else if (!kIsWeb && Platform.isWindows) {
          onError?.call(
            'Speech recognition is unavailable on Windows. Please ensure microphone access is enabled in Windows Settings > Privacy & security > Microphone ("Let desktop apps access your microphone") and a Windows speech recognition package is installed.',
          );
        } else {
          onError?.call(
            'Speech recognition is unavailable on this device.',
          );
        }
      }

      completer.complete(_isAvailable);
      return _isAvailable;
    } on Object catch (e) {
      _isAvailable = false;
      completer.complete(false);
      onError?.call('Speech recognition initialization error: $e');
      return false;
    } finally {
      _initCompleter = null;
    }
  }

  /// Starts listening to microphone and transcribing speech.
  Future<void> startListening({
    Duration listenFor = const Duration(minutes: 5),
    Duration pauseFor = const Duration(milliseconds: 2000),
    ListenMode listenMode = ListenMode.confirmation,
  }) async {
    // On Windows (SAPI) the pause timer is only reset by text results, and the
    // first hypothesis can lag 1–2s behind speech onset. A short pauseFor ends
    // the session before the user is heard, so enforce a minimum window.
    // End-of-utterance is still detected by callers' own silence timers.
    final effectivePauseFor =
        (!kIsWeb && Platform.isWindows && pauseFor < _windowsMinPauseFor)
        ? _windowsMinPauseFor
        : pauseFor;
    // If already listening, stop previous session cleanly before starting a new one
    if (_speechToText.isListening) {
      await _speechToText.stop();
      onListeningChanged(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        return;
      }
    }

    try {
      unawaited(HapticFeedback.mediumImpact());
      final started = await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
            onResultWithFinal?.call(
              result.recognizedWords,
              isFinal: result.finalResult,
            );
          } else if (result.finalResult) {
            onResultWithFinal?.call(
              '',
              isFinal: true,
            );
          }
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          listenMode: listenMode,
          listenFor: listenFor,
          pauseFor: effectivePauseFor,
        ),
      );
      if (started == false) {
        onListeningChanged(false);
        onError?.call('Could not start speech recognition session');
        return;
      }
      // Immediately reflect listening state in UI
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
