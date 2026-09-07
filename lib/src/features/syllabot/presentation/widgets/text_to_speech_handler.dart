import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/tts_config.dart';

export 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
export 'package:kortex/src/features/syllabot/presentation/widgets/tts_config.dart';

/// Cross-platform Text-To-Speech (TTS) engine for Syllabot AI spoken responses.
///
/// Features:
/// - Natural conversational delivery using platform-calibrated [TtsConfig].
/// - Intact vocal formants (pitch 1.0) to eliminate robotic/vocoder distortion.
/// - Full reactive state tracking via [isSpeakingNotifier] for UI synchronization.
/// - Intelligent speech normalization (LaTeX, Markdown, educational acronyms, times).
/// - Atomic session ID tracking for instantaneous, glitch-free barge-in interruption.
/// - Prioritises iOS Siri Enhanced/Premium neural voices and Android Google Speech Services.
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

  /// Reactive notifier for UI widgets (e.g. Chat Input Bar mic lock-out).
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  bool _isSpeaking = false;
  VoiceGender _gender = VoiceGender.female;
  double _speechRate = 1;
  late TtsConfig _config;

  final List<String> _sentenceQueue = [];
  bool _isProcessingQueue = false;
  Completer<void>? _queueDrainedCompleter;

  /// Atomic token incremented on every stop/speak to invalidate stale async callbacks.
  int _activeSessionId = 0;

  bool get isSpeaking => _isSpeaking;
  VoiceGender get voiceGender => _gender;
  double get speechRate => _speechRate;
  TtsConfig get config => _config;
  bool get hasQueuedSentences => _sentenceQueue.isNotEmpty || _isProcessingQueue;

  LocalStorageService? get _effectiveLocalStorage =>
      _localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  // ---------------------------------------------------------------------------
  // Priority Voice Lists: High-fidelity on-device Neural Voices
  // ---------------------------------------------------------------------------
  static const List<String> _iosFemaleVoicesPriority = [
    'com.apple.voice.enhanced.en-US.Ava',      // Siri Neural Ava
    'com.apple.voice.premium.en-US.Ava',
    'com.apple.voice.enhanced.en-US.Allison',  // Clear, warm
    'com.apple.voice.premium.en-US.Allison',
    'com.apple.voice.enhanced.en-US.Samantha',
    'com.apple.voice.enhanced.en-GB.Kate',     // British natural
    'com.apple.voice.enhanced.en-AU.Karen',
    'com.apple.voice.compact.en-US.Ava',
    'samantha',
    'karen',
  ];

  static const List<String> _iosMaleVoicesPriority = [
    'com.apple.voice.enhanced.en-US.Aaron',    // Siri Neural Aaron
    'com.apple.voice.premium.en-US.Aaron',
    'com.apple.voice.enhanced.en-US.Tom',      // Authentic male
    'com.apple.voice.premium.en-US.Tom',
    'com.apple.voice.enhanced.en-GB.Daniel',   // British articulate
    'com.apple.voice.premium.en-GB.Daniel',
    'com.apple.voice.enhanced.en-AU.Lee',
    'com.apple.voice.compact.en-US.Aaron',
    'daniel',
    'alex',
  ];

  static const List<String> _androidFemaleVoicesPriority = [
    'en-us-x-sfg-network', // Google Neural TTS
    'en-us-x-sfg-local',   // Google Neural Offline
    'en-us-x-iob-network',
    'en-us-x-iob-local',
    'en-us-x-iol-network',
    'en-us-x-iol-local',
    'en-gb-x-rjs-network',
    'en-US-language',
  ];

  static const List<String> _androidMaleVoicesPriority = [
    'en-us-x-tpc-network', // Google Neural TTS male
    'en-us-x-tpc-local',   // Google Neural Offline male
    'en-us-x-tpd-network',
    'en-us-x-tpd-local',
    'en-us-x-iom-network',
    'en-us-x-iom-local',
    'en-gb-x-fis-network',
    'en-US-language',
  ];

  bool _isConfigured = false;
  Map<String, String>? _cachedSelectedVoice;

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

    _config = TtsConfig.forCurrentPlatform(
      gender: _gender,
      speechRateMultiplier: _speechRate,
    );
  }

  void _initTts() {
    _flutterTts
      ..setStartHandler(() {
        _setSpeakingState(true);
      })
      ..setCompletionHandler(_handleChunkCompletion)
      ..setCancelHandler(_handleCancellation)
      ..setErrorHandler((dynamic msg) {
        _handleCancellation();
        onError?.call(msg.toString());
      });

    unawaited(_applyVoiceConfiguration());
  }

  void _setSpeakingState(bool speaking) {
    if (_isSpeaking == speaking) return;
    _isSpeaking = speaking;
    isSpeakingNotifier.value = speaking;
    onSpeakingChanged?.call(speaking);
  }

  void _handleChunkCompletion() {
    final sessionId = _activeSessionId;
    if (_sentenceQueue.isNotEmpty) {
      final nextSentence = _sentenceQueue.removeAt(0);
      // Ensure in-flight session was not aborted
      if (sessionId == _activeSessionId) {
        unawaited(_flutterTts.speak(nextSentence));
      }
    } else {
      _setSpeakingState(false);
      _isProcessingQueue = false;
      if (_queueDrainedCompleter != null &&
          !_queueDrainedCompleter!.isCompleted) {
        _queueDrainedCompleter!.complete();
        _queueDrainedCompleter = null;
      }
    }
  }

  void _handleCancellation() {
    _sentenceQueue.clear();
    _setSpeakingState(false);
    _isProcessingQueue = false;
    if (_queueDrainedCompleter != null &&
        !_queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter!.complete();
      _queueDrainedCompleter = null;
    }
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    _gender = gender;
    _config = _config.copyWith(gender: gender);
    _cachedSelectedVoice = null;
    _isConfigured = false;
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
    _config = _config.copyWith(speechRateMultiplier: rate);
    _isConfigured = false;
    await _applyVoiceConfiguration();
    try {
      await _effectiveLocalStorage?.savePreference(
        key: PrefKeys.syllabotSpeechRate,
        data: rate.toString(),
      );
    } on Object catch (_) {}
  }

  Future<void> _applyVoiceConfiguration() async {
    if (_isConfigured) return;
    try {
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.effectiveSpeechRate);
      await _flutterTts.setPitch(_config.pitch);
      await _flutterTts.setVolume(_config.volume);

      final isIos = !kIsWeb && Platform.isIOS;
      if (isIos) {
        try {
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playAndRecord,
            [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
          );
        } on Object catch (_) {}
      }

      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } on Object catch (_) {}

      await _selectBestVoice();
      _isConfigured = true;
    } on Object catch (e) {
      onError?.call(e.toString());
    }
  }

  /// Selects the most human-sounding available voice.
  Future<void> _selectBestVoice() async {
    try {
      if (_cachedSelectedVoice != null) {
        await _flutterTts.setVoice(_cachedSelectedVoice!);
        return;
      }

      final rawVoices = await _flutterTts.getVoices.timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => null,
      );
      if (rawVoices is! List) return;

      final voiceList = <Map<String, String>>[];
      for (final dynamic v in rawVoices) {
        if (v is Map) {
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? 'en-US';
          voiceList.add({'name': name, 'locale': locale});
        }
      }

      final isIos = !kIsWeb && Platform.isIOS;
      final priorities = _gender == VoiceGender.female
          ? (isIos ? _iosFemaleVoicesPriority : _androidFemaleVoicesPriority)
          : (isIos ? _iosMaleVoicesPriority : _androidMaleVoicesPriority);

      // 1. Walk explicit neural priority list
      for (final candidate in priorities) {
        final lower = candidate.toLowerCase();
        final match = voiceList.firstWhere(
          (v) =>
              v['name']!.toLowerCase() == lower ||
              v['name']!.toLowerCase().contains(lower) ||
              lower.contains(v['name']!.toLowerCase()),
          orElse: () => const {},
        );
        if (match.isNotEmpty) {
          _cachedSelectedVoice = match;
          await _flutterTts.setVoice(match);
          return;
        }
      }

      // 2. Search for any voice with high-quality neural identifiers
      final qualityKeywords = [
        'neural',
        'natural',
        'enhanced',
        'premium',
        'wavenet',
      ];
      final genderKeywords = _gender == VoiceGender.female
          ? ['ava', 'allison', 'samantha', 'karen', 'kate', 'victoria', 'female', 'woman']
          : ['aaron', 'daniel', 'tom', 'alex', 'oliver', 'lee', 'male', 'man'];

      for (final v in voiceList) {
        final nameLower = v['name']!.toLowerCase();
        final localeLower = v['locale']!.toLowerCase();
        if (!localeLower.startsWith('en')) continue;

        final hasQuality = qualityKeywords.any(nameLower.contains);
        final hasGender = genderKeywords.any(nameLower.contains);

        if (hasQuality && hasGender) {
          _cachedSelectedVoice = v;
          await _flutterTts.setVoice(v);
          return;
        }
      }

      // 3. Fallback: English voice matching requested gender
      for (final v in voiceList) {
        final nameLower = v['name']!.toLowerCase();
        final localeLower = v['locale']!.toLowerCase();
        if (!localeLower.startsWith('en')) continue;

        if (genderKeywords.any(nameLower.contains)) {
          _cachedSelectedVoice = v;
          await _flutterTts.setVoice(v);
          return;
        }
      }
    } on Object catch (_) {
      // Best effort fallback
    }
  }

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

  /// Enqueues a single sentence for immediate or sequential synthesis.
  Future<void> enqueueSentence(String rawSentence) async {
    final clean = SpeechTextNormalizer.normalize(rawSentence);
    if (clean.isEmpty) return;

    if (_queueDrainedCompleter == null ||
        _queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter = Completer<void>();
    }

    if (!_isSpeaking && !_isProcessingQueue) {
      final sessionId = ++_activeSessionId;
      _setSpeakingState(true);
      _isProcessingQueue = true;
      try {
        await _applyVoiceConfiguration();
        if (sessionId == _activeSessionId) {
          await _flutterTts.speak(clean);
        }
      } on Object catch (e) {
        _handleCancellation();
        onError?.call(e.toString());
      }
    } else {
      _sentenceQueue.add(clean);
    }
  }

  /// Synthesizes speech for [rawText], clearing any prior queued speech.
  Future<void> speak(String rawText) async {
    final clean = SpeechTextNormalizer.normalize(rawText);
    if (clean.isEmpty) return;

    await stop();

    final chunks = SpeechTextNormalizer.splitIntoChunks(clean);
    if (chunks.isEmpty) return;

    final sessionId = ++_activeSessionId;
    _queueDrainedCompleter = Completer<void>();
    _setSpeakingState(true);
    _isProcessingQueue = true;

    try {
      await _applyVoiceConfiguration();
      if (chunks.length > 1) {
        _sentenceQueue.addAll(chunks.skip(1));
      }
      if (sessionId == _activeSessionId) {
        await _flutterTts.speak(chunks.first);
      }
    } on Object catch (e) {
      _handleCancellation();
      onError?.call(e.toString());
    }
  }

  /// Clears any pending speech in the queue without interrupting active playback.
  void clearQueue() {
    _sentenceQueue.clear();
  }

  /// Waits until all queued sentences have completed synthesis and playback.
  Future<void> waitForQueueDrained() async {
    if (!_isSpeaking && !_isProcessingQueue && _sentenceQueue.isEmpty) {
      return;
    }
    await _queueDrainedCompleter?.future;
  }

  /// Immediately interrupts ongoing speech, flushes queue, and updates state.
  Future<void> stop() async {
    // Invalidate any in-flight async speak callbacks
    _activeSessionId++;
    _sentenceQueue.clear();
    _isProcessingQueue = false;

    if (_queueDrainedCompleter != null &&
        !_queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter!.complete();
      _queueDrainedCompleter = null;
    }

    try {
      await _flutterTts.stop();
    } on Object catch (e) {
      onError?.call(e.toString());
    } finally {
      _setSpeakingState(false);
    }
  }

  /// Releases resources.
  void dispose() {
    isSpeakingNotifier.dispose();
    unawaited(stop());
  }
}
