import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/profile/presentation/pages/syllabot_ai_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/socratic_reasoning_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/voice_dialogue_persona_section.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockLocalLlmEngineClient extends Mock implements LocalLlmEngineClient {}

class MockTextToSpeechService extends Mock implements TextToSpeechService {}

void main() {
  group('SyllabotAiSettingsPage Widget Tests', () {
    late MockLocalStorageService mockStorage;
    late MockLocalLlmEngineClient mockLlmClient;
    late MockTextToSpeechService mockTtsService;
    late TextToSpeechHandler ttsHandler;

    setUp(() {
      mockStorage = MockLocalStorageService();
      mockLlmClient = MockLocalLlmEngineClient();
      mockTtsService = MockTextToSpeechService();

      when(() => mockStorage.getPreference(key: any(named: 'key')))
          .thenReturn(null);
      when(
        () => mockStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockLlmClient.getAvailableModels())
          .thenAnswer((_) async => []);

      final isSpeakingNotifier = ValueNotifier<bool>(false);
      final downloadProgressNotifier = ValueNotifier<double>(0);
      final modelReadyNotifier = ValueNotifier<bool>(false);
      final downloadStatusNotifier = ValueNotifier<String>('Ready');
      final downloadingNotifier = ValueNotifier<bool>(false);

      when(() => mockTtsService.isSpeakingNotifier)
          .thenReturn(isSpeakingNotifier);
      when(() => mockTtsService.isSpeaking).thenReturn(false);
      when(() => mockTtsService.voiceGender).thenReturn(VoiceGender.female);
      when(() => mockTtsService.speechRate).thenReturn(1);
      when(() => mockTtsService.speechPitch).thenReturn(1);
      when(() => mockTtsService.kokoroVoice).thenReturn('');
      when(() => mockTtsService.lastEngineUsed)
          .thenReturn(TtsEngineType.kokoroOnDevice);
      when(() => mockTtsService.availableKokoroVoices).thenReturn([]);
      when(() => mockTtsService.kokoroDownloadProgressNotifier)
          .thenReturn(downloadProgressNotifier);
      when(() => mockTtsService.isKokoroModelReadyNotifier)
          .thenReturn(modelReadyNotifier);
      when(() => mockTtsService.kokoroDownloadStatusNotifier)
          .thenReturn(downloadStatusNotifier);
      when(() => mockTtsService.isKokoroDownloadingNotifier)
          .thenReturn(downloadingNotifier);
      when(() => mockTtsService.getAvailableVoices())
          .thenAnswer((_) async => []);
      when(() => mockTtsService.stop()).thenAnswer((_) async {});

      ttsHandler = TextToSpeechHandler(ttsService: mockTtsService);
    });

    testWidgets('renders Socratic Reasoning and Persona sections', (tester) async {
      await tester.pumpApp(
        SyllabotAiSettingsPage(
          localStorageService: mockStorage,
          localLlmEngineClient: mockLlmClient,
          ttsHandler: ttsHandler,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Syllabot AI & Neural Engine'), findsWidgets);
      expect(find.byType(SocraticReasoningSection), findsOneWidget);
      expect(find.byType(VoiceDialoguePersonaSection), findsOneWidget);
      expect(find.text('SOCRATIC REASONING ENGINE'), findsOneWidget);
      expect(find.text('VOICE DIALOGUE & TUTOR PERSONA'), findsOneWidget);
    });

    testWidgets('switching Socratic strategy chip updates active mode', (tester) async {
      await tester.pumpApp(
        SyllabotAiSettingsPage(
          localStorageService: mockStorage,
          localLlmEngineClient: mockLlmClient,
          ttsHandler: ttsHandler,
        ),
      );
      await tester.pumpAndSettle();

      final examSimChip = find.text('Exam Simulator');
      expect(examSimChip, findsOneWidget);

      await tester.tap(examSimChip);
      await tester.pumpAndSettle();

      verify(
        () => mockStorage.savePreference(
          key: PrefKeys.syllabotSocraticMode,
          data: 'examSim',
        ),
      ).called(1);
    });

    testWidgets('tapping save neural preferences persists all preferences', (tester) async {
      await tester.pumpApp(
        SyllabotAiSettingsPage(
          localStorageService: mockStorage,
          localLlmEngineClient: mockLlmClient,
          ttsHandler: ttsHandler,
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.text('Save Neural Preferences');
      expect(saveButton, findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      verify(
        () => mockStorage.savePreference(
          key: PrefKeys.syllabotSocraticMode,
          data: any(named: 'data'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
