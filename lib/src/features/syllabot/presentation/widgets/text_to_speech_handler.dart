import 'dart:async';
import 'dart:io';
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
///
/// Tuned for maximum naturalness and warmth:
/// - Prioritises iOS Enhanced/Premium neural voices (Samantha Enhanced, Ava Enhanced, etc.)
/// - Targets Google Speech Services neural voices on Android
/// - Keeps pitch at 1.0 to avoid the robotic "shifted" sound
/// - Runs at a relaxed conversational speech rate
/// - Injects micro-pauses via punctuation for natural prosody
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

  /// Base multiplier the user sets (1.0 = normal). Stored in prefs.
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

  // ---------------------------------------------------------------------------
  // iOS Enhanced/Premium neural voices — most human-sounding on-device.
  // These require the user to have downloaded the Enhanced pack in
  // Settings → Accessibility → Spoken Content → Voices → English.
  // We try Enhanced first, then Standard as fallback.
  // ---------------------------------------------------------------------------
  static const List<String> _iosFemaleVoicesPriority = [
    'com.apple.voice.enhanced.en-US.Ava',      // Neural, warm — top pick
    'com.apple.voice.premium.en-US.Ava',
    'com.apple.voice.enhanced.en-US.Allison',  // Clear, warm
    'com.apple.voice.premium.en-US.Allison',
    'com.apple.voice.enhanced.en-US.Samantha', // Classic but enhanced
    'com.apple.voice.enhanced.en-AU.Karen',    // Australian, very natural
    'com.apple.voice.enhanced.en-GB.Kate',     // British option
    'samantha',                                 // Standard fallback
    'karen',
  ];

  static const List<String> _iosMaleVoicesPriority = [
    'com.apple.voice.enhanced.en-US.Aaron',    // Very natural male
    'com.apple.voice.premium.en-US.Aaron',
    'com.apple.voice.enhanced.en-US.Tom',      // Clear, warm male
    'com.apple.voice.premium.en-US.Tom',
    'com.apple.voice.enhanced.en-GB.Daniel',   // British, articulate
    'com.apple.voice.premium.en-GB.Daniel',
    'com.apple.voice.enhanced.en-AU.Lee',      // Australian male
    'daniel',                                   // Standard fallback
    'alex',
  ];

  // ---------------------------------------------------------------------------
  // Android Google Speech Services neural voice identifiers.
  // These are the highest-quality local voices on stock Android / Google devices.
  // ---------------------------------------------------------------------------
  static const List<String> _androidFemaleVoicesPriority = [
    'en-us-x-sfg-network', // Google Neural TTS (requires network)
    'en-us-x-sfg-local',   // Google Neural TTS (offline)
    'en-us-x-iob-network',
    'en-us-x-iob-local',
    'en-us-x-iol-local',
    'en-US-language',
  ];

  static const List<String> _androidMaleVoicesPriority = [
    'en-us-x-tpc-network',  // Google Neural TTS (requires network)
    'en-us-x-tpc-local',    // Google Neural TTS (offline)
    'en-us-x-sfg-network',  // Acceptable fallback
    'en-us-x-tpd-network',
    'en-us-x-tpd-local',
    'en-US-language',
  ];

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

      // Conversational pace — 0.44 is warm and easy to follow without dragging.
      // User's multiplier shifts it slightly above or below that baseline.
      await _flutterTts.setSpeechRate(0.44 * _speechRate);
      await _flutterTts.setVolume(1);

      // Pitch 1.0 = natural. ANY deviation from 1.0 is the #1 cause of the
      // "robotic" sound. Keeping it flat lets the neural voice model control
      // its own natural intonation curve.
      await _flutterTts.setPitch(1);

      // iOS audio session — route to speaker, allow Bluetooth
      if (!kIsWeb && Platform.isIOS) {
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
          await _flutterTts.awaitSpeakCompletion(true);
        } on Object catch (_) {}
      }

      // Try to select the best available voice
      await _selectBestVoice();
    } on Object catch (e) {
      onError?.call(e.toString());
    }
  }

  /// Selects the most human-sounding available voice from a priority list.
  /// On iOS, Enhanced/Premium neural voices are dramatically better.
  /// On Android, Google's neural voice identifiers follow a predictable pattern.
  Future<void> _selectBestVoice() async {
    try {
      final rawVoices = await _flutterTts.getVoices.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () => null,
      );
      if (rawVoices is! List) return;

      // Build a normalised map: lowercased name → original map
      final voiceMap = <String, Map<dynamic, dynamic>>{};
      for (final dynamic v in rawVoices) {
        if (v is Map) {
          final name = v['name']?.toString() ?? '';
          voiceMap[name.toLowerCase()] = v;
        }
      }

      final isIos = !kIsWeb && Platform.isIOS;
      final priorities = _gender == VoiceGender.female
          ? (isIos ? _iosFemaleVoicesPriority : _androidFemaleVoicesPriority)
          : (isIos ? _iosMaleVoicesPriority : _androidMaleVoicesPriority);

      // Walk priority list — pick first one that is actually installed
      for (final candidate in priorities) {
        final lower = candidate.toLowerCase();
        // Exact match
        if (voiceMap.containsKey(lower)) {
          final v = voiceMap[lower]!;
          await _flutterTts.setVoice({
            'name': v['name'].toString(),
            'locale': v['locale']?.toString() ?? 'en-US',
          });
          return;
        }
        // Partial match (handles variant suffixes like "#ava")
        final partialMatch = voiceMap.keys
            .where((k) => k.contains(lower) || lower.contains(k))
            .firstOrNull;
        if (partialMatch != null) {
          final v = voiceMap[partialMatch]!;
          await _flutterTts.setVoice({
            'name': v['name'].toString(),
            'locale': v['locale']?.toString() ?? 'en-US',
          });
          return;
        }
      }

      // Fallback: pick any English voice that matches the gender by keyword
      final genderKeywords = _gender == VoiceGender.female
          ? ['ava', 'allison', 'samantha', 'karen', 'kate', 'victoria', 'female']
          : ['aaron', 'daniel', 'tom', 'alex', 'oliver', 'lee', 'male'];

      for (final entry in voiceMap.entries) {
        final locale = entry.value['locale']?.toString().toLowerCase() ?? '';
        if (!locale.startsWith('en')) continue;
        if (genderKeywords.any(entry.key.contains)) {
          final v = entry.value;
          await _flutterTts.setVoice({
            'name': v['name'].toString(),
            'locale': v['locale']?.toString() ?? 'en-US',
          });
          return;
        }
      }
    } on Object catch (_) {
      // Voice selection is best-effort — silently fall back to system default
    }
  }

  // ---------------------------------------------------------------------------
  // Text cleaning & naturalisation
  // ---------------------------------------------------------------------------

  /// Cleans LaTeX and markdown, expands common contractions, and injects
  /// natural micro-pauses so the TTS engine has proper prosody cues.
  static String cleanTextForSpeech(String markdown) {
    var text = markdown;

    // Remove LaTeX blocks
    text = text.replaceAll(
      RegExp(r'\$\$[\s\S]*?\$\$'),
      ', and a mathematical expression follows, ',
    );
    text = text.replaceAll(RegExp(r'\$[\s\S]*?\$'), ' formula ');

    // Expand common LaTeX commands to spoken equivalents
    text = text
        .replaceAll(r'\frac', 'over')
        .replaceAll(r'\sqrt', 'square root of')
        .replaceAll(r'\Delta', 'Delta')
        .replaceAll(r'\pm', 'plus or minus')
        .replaceAll(r'\to', 'to')
        .replaceAll(r'\neq', 'is not equal to')
        .replaceAll(r'\geq', 'is greater than or equal to')
        .replaceAll(r'\leq', 'is less than or equal to')
        .replaceAll(r'\lim', 'the limit')
        .replaceAll(r'\int', 'the integral of')
        .replaceAll(r'\partial', 'the partial derivative of')
        .replaceAll(r'\infty', 'infinity')
        .replaceAll(r'\alpha', 'alpha')
        .replaceAll(r'\beta', 'beta')
        .replaceAll(r'\gamma', 'gamma')
        .replaceAll(r'\theta', 'theta')
        .replaceAll(r'\pi', 'pi');

    // Remove markdown code blocks
    text = text.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      ', here is a code example, ',
    );
    text = text.replaceAll(RegExp('`[^`]+`'), '');

    // Remove markdown headers — preserve the text, just strip #
    text = text.replaceAll(RegExp(r'#{1,6}\s*'), '');

    // Bold / italic — strip markers, keep words
    text = text.replaceAll(RegExp(r'\*{1,3}|_{1,3}'), '');

    // Bullet points / numbered lists → natural pause before each item
    text = text.replaceAll(RegExp(r'\n\s*[-•*]\s+'), ', ');
    text = text.replaceAll(RegExp(r'\n\s*\d+\.\s+'), ', ');

    // Markdown links → keep link text only
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');

    // Remove URLs
    text = text.replaceAll(RegExp(r'https?://\S+'), '');

    // Expand common contractions so the engine doesn't stumble
    text = _expandContractions(text);

    // Convert common symbols to spoken words
    text = text
        .replaceAll(' & ', ' and ')
        .replaceAll('&', ' and ')
        .replaceAll('%', ' percent')
        .replaceAll(' > ', ' is greater than ')
        .replaceAll(' < ', ' is less than ')
        .replaceAll(' = ', ' equals ')
        .replaceAll('...', ', ')         // ellipsis → natural pause
        .replaceAll('—', ', ')           // em dash → short pause
        .replaceAll(' – ', ', ')         // en dash
        .replaceAll('(', ', ')
        .replaceAll(')', ', ');

    // Inject a short pause after colons (e.g. "Note: this means…")
    text = text.replaceAll(RegExp(r':\s+'), ': ');

    // Collapse multiple whitespace/newlines
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Collapse multiple punctuation marks
    text = text.replaceAll(RegExp(r'[,\s]+,'), ',');
    text = text.replaceAll(RegExp(r'\.\s+\.'), '.');

    return text.trim();
  }

  /// Expands common English contractions to their full form for clearer
  /// pronunciation by the TTS engine.
  static String _expandContractions(String text) {
    const contractions = {
      "won't": 'will not',
      "can't": 'cannot',
      "don't": 'do not',
      "doesn't": 'does not',
      "didn't": 'did not',
      "isn't": 'is not',
      "aren't": 'are not',
      "wasn't": 'was not',
      "weren't": 'were not',
      "hasn't": 'has not',
      "haven't": 'have not',
      "hadn't": 'had not',
      "wouldn't": 'would not',
      "couldn't": 'could not',
      "shouldn't": 'should not',
      "mustn't": 'must not',
      "that's": 'that is',
      "it's": 'it is',
      "I'm": 'I am',
      "I've": 'I have',
      "I'll": 'I will',
      "I'd": 'I would',
      "you're": 'you are',
      "you've": 'you have',
      "you'll": 'you will',
      "you'd": 'you would',
      "he's": 'he is',
      "she's": 'she is',
      "they're": 'they are',
      "they've": 'they have',
      "they'll": 'they will',
      "we're": 'we are',
      "we've": 'we have',
      "we'll": 'we will',
      "let's": 'let us',
      "there's": 'there is',
      "here's": 'here is',
      "what's": 'what is',
      "who's": 'who is',
    };
    var result = text;
    for (final entry in contractions.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Splits text into natural speech chunks at sentence and clause boundaries
  /// so the TTS engine maintains good prosody throughout a long response.
  static List<String> splitIntoChunks(String text) {
    if (text.isEmpty) return [];

    // Split on sentence-ending punctuation, keeping the delimiter
    final sentencePattern = RegExp(r'(?<=[.!?])\s+');
    final sentences = text.split(sentencePattern);

    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      // If a single sentence is already long, split on commas too
      if (trimmed.length > 180) {
        final parts = trimmed.split(RegExp(r',\s+'));
        for (final part in parts) {
          if (part.trim().isNotEmpty) {
            if (buffer.isNotEmpty) {
              chunks.add('$buffer, ${part.trim()}');
              buffer.clear();
            } else {
              chunks.add(part.trim());
            }
          }
        }
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(trimmed);
        // Flush chunk when we have a comfortable speaking length
        if (buffer.length >= 120) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

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

  /// Reads out a full text block cleanly (clears existing queue first).
  /// Splits the text into natural chunks for better prosody.
  Future<void> speak(String rawText) async {
    final clean = cleanTextForSpeech(rawText);
    if (clean.isEmpty) return;

    await stop();

    final chunks = splitIntoChunks(clean);
    if (chunks.isEmpty) return;

    _queueDrainedCompleter = Completer<void>();
    _isSpeaking = true;
    _isProcessingQueue = true;
    onSpeakingChanged?.call(true);

    try {
      await _applyVoiceConfiguration();
      // Speak first chunk immediately; remaining go to queue
      if (chunks.length > 1) {
        _sentenceQueue.addAll(chunks.skip(1));
      }
      await _flutterTts.speak(chunks.first);
    } on Object catch (e) {
      _isSpeaking = false;
      _isProcessingQueue = false;
      _sentenceQueue.clear();
      onSpeakingChanged?.call(false);
      onError?.call(e.toString());
    }
  }

  /// Waits until all queued sentences have completed synthesis and playback.
  Future<void> waitForQueueDrained() async {
    if (!_isSpeaking && !_isProcessingQueue && _sentenceQueue.isEmpty) {
      return;
    }
    await _queueDrainedCompleter?.future;
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
