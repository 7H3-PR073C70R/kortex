import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_kokoro_tts/flutter_kokoro_tts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/kokoro_model_downloader.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/tts_config.dart';
import 'package:path_provider/path_provider.dart';

/// Available synthesis engines in Kortex's tiered speech architecture.
enum TtsEngineType {
  /// Tier 1: High-fidelity cloud neural speech via Microsoft Edge online endpoint.
  edgeOnline,

  /// Tier 2: High-fidelity on-device ONNX synthesis via Kokoro TTS (24 kHz).
  kokoroOnDevice,

  /// Tier 3: Platform native speech synthesizer fallback (AVSpeechSynthesizer / Google Speech).
  systemFallback,
}

/// Abstract contract for the unified Text-to-Speech service.
abstract class TextToSpeechService {
  /// Reactive notifier for UI widgets (e.g. Chat Input Bar mic lock-out, button state).
  ValueNotifier<bool> get isSpeakingNotifier;

  /// Whether any speech is actively being synthesized or played.
  bool get isSpeaking;

  /// The active voice gender.
  VoiceGender get voiceGender;

  /// The current speech rate multiplier (e.g. 1.0).
  double get speechRate;

  /// The current speech pitch (1.0 = native natural resonance).
  double get speechPitch;

  /// The active Kokoro on-device voice name (e.g. Default, Bella, Nicole, Sarah, Adam, Michael).
  String get kokoroVoice;

  /// The active Edge online neural voice name (e.g. en-US-AriaNeural).
  String get edgeVoice;

  /// The last engine successfully used to synthesize speech.
  TtsEngineType get lastEngineUsed;

  /// List of supported on-device Kokoro voices.
  List<String> get availableKokoroVoices;

  /// Sets and persists preferred voice gender.
  Future<void> setVoiceGender(VoiceGender gender);

  /// Sets and persists speech rate multiplier.
  Future<void> setSpeechRate(double rate);

  /// Sets and persists voice pitch multiplier.
  Future<void> setSpeechPitch(double pitch);

  /// Sets and persists preferred Kokoro voice.
  Future<void> setKokoroVoice(String voiceName);

  /// Sets and persists preferred Edge neural voice.
  Future<void> setEdgeVoice(String voiceName);

  /// Generic voice name setter for backward compatibility with existing profile settings.
  Future<void> setVoiceName(String? voiceName);

  /// Synthesizes and plays [rawText] immediately, interrupting any prior speech.
  Future<void> speak(String rawText);

  /// Enqueues a single sentence for sequential synthesis/playback.
  Future<void> enqueueSentence(String rawSentence);

  /// Clears any pending speech queue without interrupting active playback.
  void clearQueue();

  /// Immediately interrupts ongoing speech, flushes queue, and resets state.
  Future<void> stop();

  /// Waits until all queued sentences have completed synthesis and playback.
  Future<void> waitForQueueDrained();

  /// Retrieves list of available system/neural voices for configuration.
  Future<List<Map<String, dynamic>>> getAvailableVoices();

  /// Notifier for Kokoro on-device model download progress (0.0 to 1.0).
  ValueNotifier<double> get kokoroDownloadProgressNotifier;

  /// Notifier for Kokoro on-device model ready status.
  ValueNotifier<bool> get isKokoroModelReadyNotifier;

  /// Notifier for Kokoro download status message.
  ValueNotifier<String> get kokoroDownloadStatusNotifier;

  /// Notifier for Kokoro downloading state.
  ValueNotifier<bool> get isKokoroDownloadingNotifier;

  /// Manually starts or resumes downloading Kokoro offline neural model.
  Future<void> startKokoroModelDownload();

  /// Releases resources.
  void dispose();
}

/// Production implementation of [TextToSpeechService].
///
/// Flow:
/// 1. `flutter_edge_tts` if there is internet.
/// 2. `flutter_kokoro_tts` if no internet (or if Edge TTS fails).
/// 3. `flutter_tts` fallback in case of exception.
class TextToSpeechServiceImpl implements TextToSpeechService {
  TextToSpeechServiceImpl({
    LocalStorageService? localStorageService,
    Connectivity? connectivity,
    AudioPlayer? audioPlayer,
    KokoroTts? kokoroTts,
    KokoroModelDownloader? kokoroModelDownloader,
    FlutterTts? flutterTts,
    this.onError,
    this.onSpeakingChanged,
  })  : _localStorageService = localStorageService,
        _connectivity = connectivity ?? Connectivity(),
        _audioPlayer = audioPlayer,
        _kokoroTts = kokoroTts,
        _downloader = kokoroModelDownloader ??
            KokoroModelDownloader(connectivity: connectivity),
        _flutterTts = flutterTts ?? FlutterTts() {
    _loadSavedPreferences();
    if (_audioPlayer != null) {
      _initAudioPlayer();
    }
    _initFlutterTts();
    unawaited(_downloader.initialize());
  }

  final LocalStorageService? _localStorageService;
  final Connectivity _connectivity;
  AudioPlayer? _audioPlayer;
  KokoroTts? _kokoroTts;
  final KokoroModelDownloader _downloader;
  final FlutterTts _flutterTts;

  final ValueChanged<String>? onError;
  final ValueChanged<bool>? onSpeakingChanged;

  @override
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  bool _isSpeaking = false;
  VoiceGender _gender = VoiceGender.female;
  double _speechRate = 1;
  double _speechPitch = 1;
  String _kokoroVoice = 'Bella';
  String _edgeVoice = 'en-US-AriaNeural';
  String? _customPlatformVoice;
  late TtsConfig _config;
  TtsEngineType _lastEngineUsed = TtsEngineType.edgeOnline;

  final List<String> _sentenceQueue = [];
  bool _isProcessingQueue = false;
  Completer<void>? _queueDrainedCompleter;
  Completer<void>? _currentChunkPlaybackCompleter;
  StreamSubscription<void>? _playerCompleteSub;
  Future<_PreparedAudioChunk?>? _prefetchFuture;
  String? _prefetchedSentence;

  int _activeSessionId = 0;
  bool _isFlutterTtsSpeaking = false;
  bool _isDisposed = false;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  VoiceGender get voiceGender => _gender;

  @override
  double get speechRate => _speechRate;

  @override
  double get speechPitch => _speechPitch;

  @override
  String get kokoroVoice => _kokoroVoice;

  @override
  String get edgeVoice => _edgeVoice;

  @override
  TtsEngineType get lastEngineUsed => _lastEngineUsed;

  @override
  List<String> get availableKokoroVoices => const [
        'Default',
        'Bella',
        'Nicole',
        'Sarah',
        'Adam',
        'Michael',
      ];

  @override
  ValueNotifier<double> get kokoroDownloadProgressNotifier =>
      _downloader.progressNotifier;

  @override
  ValueNotifier<bool> get isKokoroModelReadyNotifier =>
      _downloader.isReadyNotifier;

  @override
  ValueNotifier<String> get kokoroDownloadStatusNotifier =>
      _downloader.statusNotifier;

  @override
  ValueNotifier<bool> get isKokoroDownloadingNotifier =>
      _downloader.isDownloadingNotifier;

  @override
  Future<void> startKokoroModelDownload() =>
      _downloader.downloadModelAndVoices();

  // ---------------------------------------------------------------------------
  // Voice Mappings
  // ---------------------------------------------------------------------------

  static const Map<String, String> _kokoroToEdgeVoiceMap = {
    'Default': 'en-US-AriaNeural',
    'Bella': 'en-US-AvaNeural',
    'Nicole': 'en-US-JennyNeural',
    'Sarah': 'en-GB-SoniaNeural',
    'Adam': 'en-US-GuyNeural',
    'Michael': 'en-US-ChristopherNeural',
  };

  static const Map<String, VoiceGender> _kokoroVoiceGenderMap = {
    'Default': VoiceGender.female,
    'Bella': VoiceGender.female,
    'Nicole': VoiceGender.female,
    'Sarah': VoiceGender.female,
    'Adam': VoiceGender.male,
    'Michael': VoiceGender.male,
  };

  // ---------------------------------------------------------------------------
  // Lifecycle & Preferences
  // ---------------------------------------------------------------------------

  void _loadSavedPreferences() {
    try {
      final storage = _localStorageService;
      if (storage != null) {
        final savedGender = storage.getPreference(
          key: PrefKeys.syllabotVoiceGender,
        );
        if (savedGender != null) {
          _gender = VoiceGender.values.firstWhere(
            (g) => g.name == savedGender,
            orElse: () => VoiceGender.female,
          );
        }

        final savedRate = storage.getPreference(
          key: PrefKeys.syllabotSpeechRate,
        );
        if (savedRate != null) {
          final parsed = double.tryParse(savedRate);
          if (parsed != null && parsed > 0) {
            _speechRate = parsed;
          }
        }

        final savedPitch = storage.getPreference(
          key: PrefKeys.syllabotVoicePitch,
        );
        if (savedPitch != null) {
          final parsed = double.tryParse(savedPitch);
          if (parsed != null && parsed > 0) {
            _speechPitch = parsed;
          }
        }

        final savedKokoro = storage.getPreference(
          key: PrefKeys.kokoroVoiceName,
        );
        if (savedKokoro != null && availableKokoroVoices.contains(savedKokoro)) {
          _kokoroVoice = savedKokoro;
          _edgeVoice = _kokoroToEdgeVoiceMap[savedKokoro] ?? _edgeVoice;
        } else {
          // If gender was set, choose appropriate default Kokoro voice
          _kokoroVoice = _gender == VoiceGender.female ? 'Bella' : 'Adam';
          _edgeVoice = _kokoroToEdgeVoiceMap[_kokoroVoice] ?? _edgeVoice;
        }

        final savedEdge = storage.getPreference(
          key: PrefKeys.edgeVoiceName,
        );
        if (savedEdge != null && savedEdge.isNotEmpty) {
          _edgeVoice = savedEdge;
        }

        final savedLegacy = storage.getPreference(
          key: PrefKeys.syllabotVoiceName,
        );
        if (savedLegacy != null && savedLegacy.isNotEmpty) {
          if (availableKokoroVoices.contains(savedLegacy)) {
            _kokoroVoice = savedLegacy;
            _edgeVoice = _kokoroToEdgeVoiceMap[savedLegacy] ?? _edgeVoice;
          } else {
            _customPlatformVoice = savedLegacy;
          }
        }
      }
    } on Object catch (_) {}

    _config = TtsConfig.forCurrentPlatform(
      gender: _gender,
      speechRateMultiplier: _speechRate,
      pitch: _speechPitch,
    );
  }

  AudioPlayer? _getOrCreateAudioPlayer() {
    if (_audioPlayer != null) return _audioPlayer;
    try {
      _audioPlayer = AudioPlayer();
      _initAudioPlayer();
      return _audioPlayer;
    } on Object catch (e) {
      debugPrint('[TTS] Could not initialize AudioPlayer: $e');
      return null;
    }
  }

  void _initAudioPlayer() {
    try {
      _playerCompleteSub = _audioPlayer?.onPlayerComplete.listen((_) {
        if (_currentChunkPlaybackCompleter != null &&
            !_currentChunkPlaybackCompleter!.isCompleted) {
          _currentChunkPlaybackCompleter!.complete();
        }
      });
    } on Object catch (_) {}
  }

  void _initFlutterTts() {
    try {
      _flutterTts
        ..setStartHandler(() {
          _isFlutterTtsSpeaking = true;
        })
        ..setCompletionHandler(() {
          _isFlutterTtsSpeaking = false;
          if (_currentChunkPlaybackCompleter != null &&
              !_currentChunkPlaybackCompleter!.isCompleted) {
            _currentChunkPlaybackCompleter!.complete();
          }
        })
        ..setCancelHandler(() {
          _isFlutterTtsSpeaking = false;
          if (_currentChunkPlaybackCompleter != null &&
              !_currentChunkPlaybackCompleter!.isCompleted) {
            _currentChunkPlaybackCompleter!.complete();
          }
        })
        ..setErrorHandler((dynamic msg) {
          _isFlutterTtsSpeaking = false;
          if (_currentChunkPlaybackCompleter != null &&
              !_currentChunkPlaybackCompleter!.isCompleted) {
            _currentChunkPlaybackCompleter!.complete();
          }
          onError?.call(msg.toString());
        });

      unawaited(_configureFlutterTts());
    } on Object catch (_) {}
  }

  Future<void> _configureFlutterTts() async {
    try {
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.effectiveSpeechRate);
      await _flutterTts.setPitch(_speechPitch);
      await _flutterTts.setVolume(1);

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

      if (_customPlatformVoice != null && _customPlatformVoice!.isNotEmpty) {
        await _flutterTts.setVoice({
          'name': _customPlatformVoice!,
          'locale': _config.language,
        });
      }
    } on Object catch (_) {}
  }

  void _setSpeakingState(bool speaking) {
    if (_isSpeaking == speaking) return;
    _isSpeaking = speaking;
    isSpeakingNotifier.value = speaking;
    onSpeakingChanged?.call(speaking);
  }

  // ---------------------------------------------------------------------------
  // Settings Setters
  // ---------------------------------------------------------------------------

  @override
  Future<void> setVoiceGender(VoiceGender gender) async {
    _gender = gender;
    _config = _config.copyWith(gender: gender);
    if (!availableKokoroVoices.contains(_kokoroVoice) ||
        _kokoroVoiceGenderMap[_kokoroVoice] != gender) {
      _kokoroVoice = gender == VoiceGender.female ? 'Bella' : 'Adam';
      _edgeVoice = _kokoroToEdgeVoiceMap[_kokoroVoice] ?? _edgeVoice;
    }
    await _configureFlutterTts();
    try {
      await _localStorageService?.savePreference(
        key: PrefKeys.syllabotVoiceGender,
        data: gender.name,
      );
      await _localStorageService?.savePreference(
        key: PrefKeys.kokoroVoiceName,
        data: _kokoroVoice,
      );
    } on Object catch (_) {}
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    _config = _config.copyWith(speechRateMultiplier: rate);
    await _configureFlutterTts();
    try {
      await _localStorageService?.savePreference(
        key: PrefKeys.syllabotSpeechRate,
        data: rate.toString(),
      );
    } on Object catch (_) {}
  }

  @override
  Future<void> setSpeechPitch(double pitch) async {
    _speechPitch = pitch;
    _config = _config.copyWith(pitch: pitch);
    await _configureFlutterTts();
    try {
      await _localStorageService?.savePreference(
        key: PrefKeys.syllabotVoicePitch,
        data: pitch.toString(),
      );
    } on Object catch (_) {}
  }

  @override
  Future<void> setKokoroVoice(String voiceName) async {
    if (!availableKokoroVoices.contains(voiceName)) return;
    _kokoroVoice = voiceName;
    final correspondingGender = _kokoroVoiceGenderMap[voiceName];
    if (correspondingGender != null) {
      _gender = correspondingGender;
      _config = _config.copyWith(gender: correspondingGender);
    }
    _edgeVoice = _kokoroToEdgeVoiceMap[voiceName] ?? _edgeVoice;
    await _configureFlutterTts();
    try {
      await _localStorageService?.savePreference(
        key: PrefKeys.kokoroVoiceName,
        data: voiceName,
      );
      await _localStorageService?.savePreference(
        key: PrefKeys.syllabotVoiceName,
        data: voiceName,
      );
      if (correspondingGender != null) {
        await _localStorageService?.savePreference(
          key: PrefKeys.syllabotVoiceGender,
          data: correspondingGender.name,
        );
      }
    } on Object catch (_) {}
  }

  @override
  Future<void> setEdgeVoice(String voiceName) async {
    _edgeVoice = voiceName;
    try {
      await _localStorageService?.savePreference(
        key: PrefKeys.edgeVoiceName,
        data: voiceName,
      );
    } on Object catch (_) {}
  }

  @override
  Future<void> setVoiceName(String? voiceName) async {
    if (voiceName == null || voiceName.isEmpty) {
      _customPlatformVoice = null;
      return;
    }
    if (availableKokoroVoices.contains(voiceName)) {
      await setKokoroVoice(voiceName);
    } else {
      _customPlatformVoice = voiceName;
      _edgeVoice = voiceName;
      await _configureFlutterTts();
      try {
        await _localStorageService?.savePreference(
          key: PrefKeys.syllabotVoiceName,
          data: voiceName,
        );
      } on Object catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Available Voices Discovery
  // ---------------------------------------------------------------------------

  @override
  Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    final list = <Map<String, dynamic>>[];

    // 1. Add Kokoro On-Device Voices
    for (final v in availableKokoroVoices) {
      final gender = _kokoroVoiceGenderMap[v] ?? VoiceGender.female;
      list.add({
        'name': v,
        'locale': 'en-US (Kokoro Neural Offline)',
        'isNeural': true,
        'gender': gender,
        'engine': 'Kokoro On-Device',
      });
    }

    // 2. Add System Voices via FlutterTts as fallback discovery
    try {
      final rawVoices = await _flutterTts.getVoices.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => null,
      );
      if (rawVoices is List) {
        for (final dynamic v in rawVoices) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? 'en-US';
            if (!locale.toLowerCase().startsWith('en')) continue;

            final nameLower = name.toLowerCase();
            final isNeural = nameLower.contains('neural') ||
                nameLower.contains('enhanced') ||
                nameLower.contains('natural') ||
                nameLower.contains('siri');

            list.add({
              'name': name,
              'locale': locale,
              'isNeural': isNeural,
              'gender': nameLower.contains('female') ||
                      nameLower.contains('ava') ||
                      nameLower.contains('allison') ||
                      nameLower.contains('samantha')
                  ? VoiceGender.female
                  : VoiceGender.male,
              'engine': 'System TTS',
            });
          }
        }
      }
    } on Object catch (_) {}

    return list;
  }

  // ---------------------------------------------------------------------------
  // Public Speech API
  // ---------------------------------------------------------------------------

  @override
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

    _sentenceQueue.addAll(chunks);
    unawaited(_processQueue(sessionId));
  }

  @override
  Future<void> enqueueSentence(String rawSentence) async {
    final clean = SpeechTextNormalizer.normalize(rawSentence);
    if (clean.isEmpty) return;

    if (_queueDrainedCompleter == null || _queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter = Completer<void>();
    }

    final chunks = SpeechTextNormalizer.splitIntoChunks(clean);
    if (chunks.isEmpty) return;

    _sentenceQueue.addAll(chunks);

    if (!_isSpeaking && !_isProcessingQueue) {
      final sessionId = ++_activeSessionId;
      _setSpeakingState(true);
      _isProcessingQueue = true;
      unawaited(_processQueue(sessionId));
    } else {
      _prefetchNextIfNeeded(_activeSessionId);
    }
  }

  @override
  void clearQueue() {
    _sentenceQueue.clear();
    _prefetchFuture = null;
    _prefetchedSentence = null;
  }

  @override
  Future<void> waitForQueueDrained() async {
    if (!_isSpeaking && !_isProcessingQueue && _sentenceQueue.isEmpty) {
      return;
    }
    await _queueDrainedCompleter?.future;
  }

  @override
  Future<void> stop() async {
    _activeSessionId++;
    _sentenceQueue.clear();
    _prefetchFuture = null;
    _prefetchedSentence = null;
    _isProcessingQueue = false;

    if (_currentChunkPlaybackCompleter != null &&
        !_currentChunkPlaybackCompleter!.isCompleted) {
      _currentChunkPlaybackCompleter!.complete();
    }
    _currentChunkPlaybackCompleter = null;

    if (_queueDrainedCompleter != null &&
        !_queueDrainedCompleter!.isCompleted) {
      _queueDrainedCompleter!.complete();
      _queueDrainedCompleter = null;
    }

    try {
      await _audioPlayer?.stop();
    } on Object catch (_) {}

    try {
      if (_isFlutterTtsSpeaking) {
        await _flutterTts.stop();
        _isFlutterTtsSpeaking = false;
      }
    } on Object catch (_) {}

    _setSpeakingState(false);
  }

  // ---------------------------------------------------------------------------
  // Internal Queue Execution & Pipelined Synthesis
  // ---------------------------------------------------------------------------

  void _prefetchNextIfNeeded(int sessionId) {
    if (sessionId != _activeSessionId) return;
    if (_sentenceQueue.isNotEmpty && _prefetchFuture == null) {
      final next = _sentenceQueue.first;
      _prefetchedSentence = next;
      _prefetchFuture = _synthesizeSentenceTiered(next, sessionId);
    }
  }

  Future<void> _processQueue(int sessionId) async {
    while (_sentenceQueue.isNotEmpty && sessionId == _activeSessionId) {
      final sentence = _sentenceQueue.removeAt(0);

      _PreparedAudioChunk? chunk;
      if (_prefetchedSentence == sentence && _prefetchFuture != null) {
        chunk = await _prefetchFuture;
        _prefetchFuture = null;
        _prefetchedSentence = null;
      } else {
        _prefetchFuture = null;
        _prefetchedSentence = null;
        chunk = await _synthesizeSentenceTiered(sentence, sessionId);
      }

      if (sessionId != _activeSessionId || chunk == null) continue;

      // Pipeline synthesis of the next sentence in the background while this chunk plays
      _prefetchNextIfNeeded(sessionId);

      try {
        await _playChunk(chunk);
      } on Object catch (e) {
        onError?.call(e.toString());
      }

      if (_sentenceQueue.isNotEmpty && sessionId == _activeSessionId) {
        final next = _sentenceQueue.first;
        final isSectionBreak = next.startsWith('Question ') ||
            next.startsWith('Section ') ||
            next.startsWith('Part ') ||
            next.startsWith('Topic ') ||
            next.startsWith('Week ');

        final trimmedSentence = sentence.trim();
        final endsWithTerminalPunctuation = trimmedSentence.endsWith('.') ||
            trimmedSentence.endsWith('!') ||
            trimmedSentence.endsWith('?');

        var pauseMs = 0;
        if (isSectionBreak) {
          pauseMs = (_config.sentencePauseMs * 2).clamp(200, 350);
        } else if (endsWithTerminalPunctuation) {
          pauseMs = _config.sentencePauseMs;
        } else {
          pauseMs = 0;
        }

        if (pauseMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: pauseMs));
        }
      }
    }

    if (sessionId == _activeSessionId) {
      _prefetchFuture = null;
      _prefetchedSentence = null;
      _isProcessingQueue = false;
      _setSpeakingState(false);
      if (_queueDrainedCompleter != null &&
          !_queueDrainedCompleter!.isCompleted) {
        _queueDrainedCompleter!.complete();
        _queueDrainedCompleter = null;
      }
    }
  }

  /// Tiered synthesis router:
  /// 1. flutter_edge_tts if internet is available.
  /// 2. flutter_kokoro_tts if offline or Edge TTS fails.
  /// 3. flutter_tts fallback in case of exception.
  Future<_PreparedAudioChunk?> _synthesizeSentenceTiered(
    String sentence,
    int sessionId,
  ) async {
    if (sessionId != _activeSessionId || sentence.trim().isEmpty) return null;

    final isOnline = await _checkInternetConnection();

    // -------------------------------------------------------------------------
    // Tier 1: flutter_edge_tts (Online)
    // -------------------------------------------------------------------------
    if (isOnline) {
      try {
        final bytes = await _synthesizeWithEdgeTts(sentence, sessionId);
        if (bytes != null && bytes.isNotEmpty) {
          return _PreparedAudioChunk(
            sessionId: sessionId,
            text: sentence,
            bytes: bytes,
            extension: 'mp3',
            engine: TtsEngineType.edgeOnline,
          );
        }
      } on Object catch (e) {
        debugPrint('[TTS] Edge TTS failed, falling back to Kokoro: $e');
      }
    }

    if (sessionId != _activeSessionId) return null;

    // -------------------------------------------------------------------------
    // Tier 2: flutter_kokoro_tts (Offline / High-Quality On-Device)
    // -------------------------------------------------------------------------
    try {
      final wavBytes = await _synthesizeWithKokoroTts(sentence, sessionId);
      if (wavBytes != null && wavBytes.isNotEmpty) {
        return _PreparedAudioChunk(
          sessionId: sessionId,
          text: sentence,
          bytes: wavBytes,
          extension: 'wav',
          engine: TtsEngineType.kokoroOnDevice,
        );
      }
    } on Object catch (e) {
      debugPrint('[TTS] Kokoro TTS failed, falling back to system TTS: $e');
    }

    if (sessionId != _activeSessionId) return null;

    // -------------------------------------------------------------------------
    // Tier 3: flutter_tts (System native fallback)
    // -------------------------------------------------------------------------
    return _PreparedAudioChunk(
      sessionId: sessionId,
      text: sentence,
      engine: TtsEngineType.systemFallback,
    );
  }

  Future<void> _playChunk(_PreparedAudioChunk chunk) async {
    if (chunk.sessionId != _activeSessionId) return;

    _lastEngineUsed = chunk.engine;

    if (chunk.bytes != null && chunk.extension != null) {
      await _playBytes(
        chunk.bytes!,
        extension: chunk.extension!,
        sessionId: chunk.sessionId,
      );
    } else {
      await _speakWithFlutterTts(chunk.text, chunk.sessionId);
    }
  }

  // ---------------------------------------------------------------------------
  // Tier 1: Microsoft Edge Online TTS
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _synthesizeWithEdgeTts(String text, int sessionId) async {
    final edgeTts = FlutterEdgeTts(
      voice: _edgeVoice,
    );

    try {
      final ratePercent = ((_speechRate - 1.0) * 100).round();
      final rateStr = '${ratePercent >= 0 ? '+' : ''}$ratePercent%';

      final pitchHz = ((_speechPitch - 1.0) * 50).round();
      final pitchStr = '${pitchHz >= 0 ? '+' : ''}${pitchHz}Hz';

      final prosody = EdgeTtsProsody(
        rate: rateStr,
        pitch: pitchStr,
      );

      final result = await edgeTts.synthesize(text, prosody: prosody);
      if (result.audioBytes.isEmpty) return null;
      if (sessionId != _activeSessionId) return null;

      return result.audioBytes;
    } finally {
      await edgeTts.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Tier 2: Kokoro On-Device TTS
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _synthesizeWithKokoroTts(String text, int sessionId) async {
    if (!_downloader.isReadyNotifier.value) {
      final isReady = await _downloader.isReady();
      if (!isReady) {
        unawaited(_downloader.startAutoDownload());
        debugPrint(
          '[TTS] Kokoro model not ready yet. Auto-download initiated, using fallback.',
        );
        return null;
      }
    }

    final kokoro = _kokoroTts ??= KokoroTts();
    await kokoro.initialize();

    final audioSamples = await kokoro.generate(
      text,
      voice: _kokoroVoice,
      speed: _speechRate,
    );

    if (audioSamples.isEmpty) return null;
    if (sessionId != _activeSessionId) return null;

    final wavBytes = buildWavBytes(audioSamples, kokoro.sampleRate);
    return wavBytes;
  }

  // ---------------------------------------------------------------------------
  // Tier 3: FlutterTts Native Fallback
  // ---------------------------------------------------------------------------

  Future<void> _speakWithFlutterTts(String text, int sessionId) async {
    if (sessionId != _activeSessionId) return;

    _currentChunkPlaybackCompleter = Completer<void>();
    _isFlutterTtsSpeaking = true;
    await _flutterTts.speak(text);

    // Wait until speak completes or is interrupted
    if (_currentChunkPlaybackCompleter != null) {
      await _currentChunkPlaybackCompleter!.future;
    }
  }

  // ---------------------------------------------------------------------------
  // Audio Playback Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _playBytes(
    Uint8List bytes, {
    required String extension,
    required int sessionId,
  }) async {
    if (sessionId != _activeSessionId) return false;

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/kortex_tts_${sessionId}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes);

    if (sessionId != _activeSessionId) {
      unawaited(file.delete().catchError((_) => file));
      return false;
    }

    final player = _getOrCreateAudioPlayer();
    if (player == null) return false;

    _currentChunkPlaybackCompleter = Completer<void>();
    try {
      await player.play(DeviceFileSource(file.path));
      await _currentChunkPlaybackCompleter!.future;
      return true;
    } finally {
      unawaited(file.delete().catchError((_) => file));
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any(
        (c) =>
            c == ConnectivityResult.wifi ||
            c == ConnectivityResult.mobile ||
            c == ConnectivityResult.ethernet,
      );
    } on Object catch (_) {
      return false;
    }
  }

  /// Builds a valid RIFF/WAVE 16-bit PCM header and payload from Float32 audio samples.
  static Uint8List buildWavBytes(Float32List samples, int sampleRate) {
    final numSamples = samples.length;
    final dataLen = numSamples * 2;
    const headerLen = 44;
    final total = headerLen + dataLen;
    final out = Uint8List(total);
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
    add(_uint16ToBytes(1)); // PCM format = 1
    add(_uint16ToBytes(1)); // Mono channel = 1
    add(_uint32ToBytes(sampleRate));
    add(_uint32ToBytes(sampleRate * 2)); // Byte rate: sampleRate * channels * bitsPerSample / 8
    add(_uint16ToBytes(2)); // Block align: channels * bitsPerSample / 8
    add(_uint16ToBytes(16)); // Bits per sample = 16
    add('data'.codeUnits);
    add(_uint32ToBytes(dataLen));

    for (var i = 0; i < numSamples; i++) {
      var s = samples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      final int16 = (s * 32767).round();
      out[offset++] = int16 & 0xff;
      out[offset++] = (int16 >> 8) & 0xff;
    }
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
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(stop());
    _downloader.dispose();
    unawaited(_playerCompleteSub?.cancel());
    unawaited(_audioPlayer?.dispose());
    unawaited(_kokoroTts?.dispose());
    isSpeakingNotifier.dispose();
  }
}

/// Internal container for a synthesized audio chunk awaiting or undergoing playback.
class _PreparedAudioChunk {
  const _PreparedAudioChunk({
    required this.sessionId,
    required this.text,
    required this.engine, this.bytes,
    this.extension,
  });

  final int sessionId;
  final String text;
  final Uint8List? bytes;
  final String? extension;
  final TtsEngineType engine;
}
