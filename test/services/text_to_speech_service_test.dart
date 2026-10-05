import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/text_to_speech_service.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

class FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => _data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAllPreferences() async {
    _data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextToSpeechService & Kokoro TTS Integration', () {
    late FakeLocalStorageService memoryStorage;
    late TextToSpeechService ttsService;

    setUp(() {
      memoryStorage = FakeLocalStorageService();
      ttsService = TextToSpeechServiceImpl(
        localStorageService: memoryStorage,
      );
    });

    test('exposes all 6 Kokoro voices required by specifications', () {
      expect(
        ttsService.availableKokoroVoices,
        equals(['Default', 'Bella', 'Nicole', 'Sarah', 'Adam', 'Michael']),
      );
    });

    test('loads default Kokoro voice and initial speech parameters', () {
      expect(ttsService.kokoroVoice, equals('Bella'));
      expect(ttsService.speechRate, equals(1.0));
      expect(ttsService.speechPitch, equals(1.0));
      expect(ttsService.voiceGender, equals(VoiceGender.female));
      expect(ttsService.isSpeaking, isFalse);
    });

    test('setting Kokoro voice updates preferences and gender correctly',
        () async {
      await ttsService.setKokoroVoice('Adam');

      expect(ttsService.kokoroVoice, equals('Adam'));
      expect(ttsService.voiceGender, equals(VoiceGender.male));
      expect(
        memoryStorage.getPreference(key: PrefKeys.kokoroVoiceName),
        equals('Adam'),
      );
      expect(
        memoryStorage.getPreference(key: PrefKeys.syllabotVoiceGender),
        equals(VoiceGender.male.name),
      );

      await ttsService.setKokoroVoice('Sarah');
      expect(ttsService.kokoroVoice, equals('Sarah'));
      expect(ttsService.voiceGender, equals(VoiceGender.female));
    });

    test('speech rate and pitch adjustments persist in local storage',
        () async {
      await ttsService.setSpeechRate(1.25);
      expect(ttsService.speechRate, equals(1.25));
      expect(
        memoryStorage.getPreference(key: PrefKeys.syllabotSpeechRate),
        equals('1.25'),
      );

      await ttsService.setSpeechPitch(1.1);
      expect(ttsService.speechPitch, equals(1.1));
      expect(
        memoryStorage.getPreference(key: PrefKeys.syllabotVoicePitch),
        equals('1.1'),
      );
    });

    test('TextToSpeechHandler delegates smoothly to TextToSpeechService',
        () async {
      final handler = TextToSpeechHandler(
        ttsService: ttsService,
      );

      expect(handler.customVoiceName, equals('Bella'));
      expect(handler.availableKokoroVoices.length, equals(6));

      await handler.setKokoroVoice('Michael');
      expect(handler.customVoiceName, equals('Michael'));
      expect(handler.voiceGender, equals(VoiceGender.male));
      expect(ttsService.kokoroVoice, equals('Michael'));

      handler.dispose();
    });

    test('loads persisted Kokoro voice preference on fresh initialization',
        () async {
      await memoryStorage.savePreference(
        key: PrefKeys.kokoroVoiceName,
        data: 'Nicole',
      );
      await memoryStorage.savePreference(
        key: PrefKeys.syllabotSpeechRate,
        data: '1.2',
      );

      final freshService = TextToSpeechServiceImpl(
        localStorageService: memoryStorage,
      );

      expect(freshService.kokoroVoice, equals('Nicole'));
      expect(freshService.speechRate, equals(1.2));
      expect(freshService.voiceGender, equals(VoiceGender.female));
    });
  });
}
