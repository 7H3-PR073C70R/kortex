import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';

/// Available synthesized voice gender for Syllabot AI speech.
enum VoiceGender {
  female,
  male,
}

/// Cross-platform Text-To-Speech (TTS) engine for Syllabot AI spoken responses.
class TextToSpeechHandler {
  TextToSpeechHandler({
    this.onSpeakingChanged,
    this.onError,
    LocalStorageService? localStorageService,
  }) : _localStorageService = localStorageService {
    _loadSavedPreferences();
    _initTts();
  }

  final ValueChanged<bool>? onSpeakingChanged;
  final ValueChanged<String>? onError;
  final LocalStorageService? _localStorageService;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  VoiceGender _gender = VoiceGender.female;
  double _speechRate = 1;

  final List<String> _sentenceQueue = [];
  bool _isProcessingQueue = false;
  Completer<void>? _queueDrainedCompleter;

  bool get isSpeaking => _isSpeaking;
  VoiceGender get voiceGender => _gender;
  double get speechRate => _speechRate;
  bool get hasQueuedSentences => _sentenceQueue.isNotEmpty || _isProcessingQueue;

  LocalStorageService? get _effectiveLocalStorage =>
      _localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  void _loadSavedPreferences() {
    try {
      final storage = _effectiveLocalStorage;
      if (storage != null) {
        final savedGender =
            storage.getPreference(key: PrefKeys.syllabotVoiceGender);
        if (savedGender != null) {
          _gender = VoiceGender.values.firstWhere(
            (g) => g.name == savedGender,
            orElse: () => VoiceGender.female,
          );
        }
        final savedRate =
            storage.getPreference(key: PrefKeys.syllabotSpeechRate);
        if (savedRate != null) {
          final parsed = double.tryParse(savedRate);
          if (parsed != null && parsed > 0) {
            _speechRate = parsed;
          }
        }
      }
    } on Object catch (_) {}
  }

  void _initTts() {
    _flutterTts
      ..setStartHandler(() {
        _isSpeaking = true;
        onSpeakingChanged?.call(true);
      })
      ..setCompletionHandler(() {
        if (_sentenceQueue.isNotEmpty) {
          final nextSentence = _sentenceQueue.removeAt(0);
          unawaited(_flutterTts.speak(nextSentence));
        } else {
          _isSpeaking = false;
          _isProcessingQueue = false;
          onSpeakingChanged?.call(false);
          if (_queueDrainedCompleter != null &&
              !_queueDrainedCompleter!.isCompleted) {
            _queueDrainedCompleter!.complete();
            _queueDrainedCompleter = null;
          }
        }
      })
      ..setCancelHandler(() {
        _sentenceQueue.clear();
        _isSpeaking = false;
        _isProcessingQueue = false;
        onSpeakingChanged?.call(false);
        if (_queueDrainedCompleter != null &&
            !_queueDrainedCompleter!.isCompleted) {
          _queueDrainedCompleter!.complete();
          _queueDrainedCompleter = null;
        }
      })
      ..setErrorHandler((dynamic msg) {
        _sentenceQueue.clear();
        _isSpeaking = false;
        _isProcessingQueue = false;
        onSpeakingChanged?.call(false);
        if (_queueDrainedCompleter != null &&
            !_queueDrainedCompleter!.isCompleted) {
          _queueDrainedCompleter!.complete();
          _queueDrainedCompleter = null;
        }
        onError?.call(msg.toString());
      });

    unawaited(_applyVoiceConfiguration());
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    _gender = gender;
    await _applyVoiceConfiguration();
    try {
      await _effectiveLocalStorage?.savePreference(
        key: PrefKeys.syllabotVoiceGender,
        data: gender.name,
      );
    } on Object catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _applyVoiceConfiguration();
    try {
      await _effectiveLocalStorage?.savePreference(
        key: PrefKeys.syllabotSpeechRate,
        data: rate.toString(),
      );
    } on Object catch (_) {}
  }

  Future<void> _applyVoiceConfiguration() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48 * _speechRate);
      await _flutterTts.setVolume(1);

      // Explicitly configure audio session category for iOS speaker playback
      try {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
        );
        await _flutterTts.awaitSpeakCompletion(true);
      } on Object catch (_) {}

      if (_gender == VoiceGender.female) {
        await _flutterTts.setPitch(1.15);
      } else {
        await _flutterTts.setPitch(0.85);
      }

      // Query available voices safely with timeout
      try {
        final voices = await _flutterTts.getVoices.timeout(
          const Duration(milliseconds: 600),
          onTimeout: () => null,
        );
        if (voices is List) {
          for (final dynamic voice in voices) {
            if (voice is Map) {
              final name = voice['name']?.toString().toLowerCase() ?? '';
              final locale = voice['locale']?.toString().toLowerCase() ?? '';
              if (locale.contains('en')) {
                if (_gender == VoiceGender.female &&
                    (name.contains('female') ||
                        name.contains('samantha') ||
                        name.contains('karen') ||
                        name.contains('zira') ||
                        name.contains('victoria'))) {
                  await _flutterTts.setVoice({
                    'name': voice['name'].toString(),
                    'locale': voice['locale'].toString(),
                  });
                  break;
                } else if (_gender == VoiceGender.male &&
                    (name.contains('male') ||
                        name.contains('daniel') ||
                        name.contains('david') ||
                        name.contains('alex') ||
                        name.contains('guy') ||
                        name.contains('oliver'))) {
                  await _flutterTts.setVoice({
                    'name': voice['name'].toString(),
                    'locale': voice['locale'].toString(),
                  });
                  break;
                }
              }
            }
          }
        }
      } on Object catch (_) {}
    } on Object catch (e) {
      onError?.call(e.toString());
    }
  }

  /// Clean LaTeX and markdown markup before speaking
  static String cleanTextForSpeech(String markdown) {
    var text = markdown;

    // Remove LaTeX delimiters and replace common math terms
    text = text.replaceAll(
      RegExp(r'\$\$[\s\S]*?\$\$'),
      ' [Mathematical Proof] ',
    );
    text = text.replaceAll(RegExp(r'\$[\s\S]*?\$'), ' [formula] ');
    text = text.replaceAll(r'\frac', 'fraction of');
    text = text.replaceAll(r'\sqrt', 'square root of');
    text = text.replaceAll(r'\Delta', 'Delta');
    text = text.replaceAll(r'\pm', 'plus or minus');
    text = text.replaceAll(r'\to', 'approaches');
    text = text.replaceAll(r'\neq', 'not equal to');
    text = text.replaceAll(r'\lim', 'limit');
    text = text.replaceAll(r'\int', 'integral of');
    text = text.replaceAll(r'\partial', 'partial derivative of');

    // Remove markdown headers, bold, bullets, code blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' [Code snippet] ');
    text = text.replaceAll(RegExp(r'#+\s*'), '');
    text = text.replaceAll(RegExp(r'\*\*|__'), '');
    text = text.replaceAll(RegExp(r'•|\*|-'), '');
    text = text.replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Enqueues a single sentence for immediate or sequential speech synthesis.
  Future<void> enqueueSentence(String rawSentence) async {
    final clean = cleanTextForSpeech(rawSentence);
    if (clean.isEmpty) return;

    if (_queueDrainedCompleter == null ||
        _queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter = Completer<void>();
    }

    if (!_isSpeaking && !_isProcessingQueue) {
      _isSpeaking = true;
      _isProcessingQueue = true;
      onSpeakingChanged?.call(true);
      try {
        await _applyVoiceConfiguration();
        await _flutterTts.speak(clean);
      } on Object catch (e) {
        _isSpeaking = false;
        _isProcessingQueue = false;
        onSpeakingChanged?.call(false);
        onError?.call(e.toString());
      }
    } else {
      _sentenceQueue.add(clean);
    }
  }

  /// Waits until all queued sentences have completed synthesis and playback.
  Future<void> waitForQueueDrained() async {
    if (!_isSpeaking && !_isProcessingQueue && _sentenceQueue.isEmpty) {
      return;
    }
    await _queueDrainedCompleter?.future;
  }

  /// Reads out text cleanly (clears existing queue).
  Future<void> speak(String rawText) async {
    final clean = cleanTextForSpeech(rawText);
    if (clean.isEmpty) return;

    await stop();

    _isSpeaking = true;
    _isProcessingQueue = true;
    onSpeakingChanged?.call(true);

    try {
      await _applyVoiceConfiguration();
      await _flutterTts.speak(clean);
    } on Object catch (e) {
      _isSpeaking = false;
      _isProcessingQueue = false;
      onSpeakingChanged?.call(false);
      onError?.call(e.toString());
    }
  }

  /// Stops ongoing speech and clears all buffered sentences.
  Future<void> stop() async {
    _sentenceQueue.clear();
    _isProcessingQueue = false;
    if (_queueDrainedCompleter != null &&
        !_queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter!.complete();
      _queueDrainedCompleter = null;
    }

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      onSpeakingChanged?.call(false);
    } on Object catch (e) {
      onError?.call(e.toString());
    }
  }

  /// Releases resources.
  void dispose() {
    unawaited(stop());
  }
}
