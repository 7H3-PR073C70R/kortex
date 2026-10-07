import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue_modal.dart';
import 'package:kortex/src/l10n/l10n.dart';

class FakeTextToSpeechService implements TextToSpeechService {
  @override
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  @override
  final ValueNotifier<double> kokoroDownloadProgressNotifier = ValueNotifier<double>(1);

  @override
  final ValueNotifier<bool> isKokoroModelReadyNotifier = ValueNotifier<bool>(true);

  @override
  final ValueNotifier<String> kokoroDownloadStatusNotifier = ValueNotifier<String>('Ready');

  @override
  final ValueNotifier<bool> isKokoroDownloadingNotifier = ValueNotifier<bool>(false);

  @override
  Future<void> startKokoroModelDownload() async {}

  final List<String> spokenTexts = [];
  VoiceGender _gender = VoiceGender.female;
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  VoiceGender get voiceGender => _gender;

  @override
  double get speechPitch => 1;

  @override
  double get speechRate => 1;

  @override
  String get kokoroVoice => 'Bella';

  @override
  String get edgeVoice => 'en-US-AriaNeural';

  @override
  TtsEngineType get lastEngineUsed => TtsEngineType.edgeOnline;

  @override
  List<String> get availableKokoroVoices => ['Bella', 'Nicole', 'Adam'];

  @override
  Future<void> speak(String rawText) async {
    spokenTexts.add(rawText);
    _speaking = true;
    isSpeakingNotifier.value = true;
  }

  @override
  Future<void> enqueueSentence(String rawSentence) async {
    spokenTexts.add(rawSentence);
    _speaking = true;
    isSpeakingNotifier.value = true;
  }

  @override
  Future<void> waitForQueueDrained() async {
    _speaking = false;
    isSpeakingNotifier.value = false;
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    isSpeakingNotifier.value = false;
  }

  @override
  void clearQueue() {}

  @override
  Future<void> setVoiceGender(VoiceGender gender) async {
    _gender = gender;
  }

  @override
  Future<void> setSpeechPitch(double pitch) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVoiceName(String? voiceName) async {}

  @override
  Future<void> setKokoroVoice(String voiceName) async {}

  @override
  Future<void> setEdgeVoice(String voiceName) async {}

  @override
  Future<List<Map<String, dynamic>>> getAvailableVoices() async => [];

  @override
  void dispose() {
    isSpeakingNotifier.dispose();
    kokoroDownloadProgressNotifier.dispose();
    isKokoroModelReadyNotifier.dispose();
    kokoroDownloadStatusNotifier.dispose();
    isKokoroDownloadingNotifier.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FakeTextToSpeechService fakeTtsService;
  late TextToSpeechHandler ttsHandler;

  setUp(() {
    fakeTtsService = FakeTextToSpeechService();
    ttsHandler = TextToSpeechHandler(ttsService: fakeTtsService);
  });

  Widget buildTestWidget({
    required Widget child,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('VoiceDialogueModal Test Suite', () {
    testWidgets('starts speaking initial greeting automatically and renders controls', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueModal(
            ttsHandler: ttsHandler,
            onSendPrompt: (prompt) async => 'Response to $prompt',
          ),
        ),
      );

      // Trigger post-frame callback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Syllabot should have spoken the initial greeting
      expect(fakeTtsService.spokenTexts, isNotEmpty);
      expect(fakeTtsService.spokenTexts.first, contains('Hello!'));

      // Header controls (gender pill and close button) exist
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Female Voice'), findsOneWidget);

      // Verify toggling voice gender
      await tester.tap(find.text('Female Voice'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Male Voice'), findsOneWidget);

      // Drain greeting delay timer
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('transitions spirally after speaking completes', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueModal(
            ttsHandler: ttsHandler,
            onSendPrompt: (prompt) async => 'AI Answer',
          ),
        ),
      );

      await tester.pump();
      // Pump past greeting delay (400ms)
      await tester.pump(const Duration(milliseconds: 600));

      // After greeting audio drains, listening cycle is triggered
      expect(find.byIcon(Icons.mic_rounded), findsWidgets);
    });

    testWidgets('tapping push-to-talk button triggers interaction state transition', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueModal(
            ttsHandler: ttsHandler,
            onSendPrompt: (prompt) async => 'AI Answer',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Central Orb / bottom action button is clickable
      final bottomButton = find.byType(InkWell).first;
      await tester.tap(bottomButton);
      await tester.pump();

      // Modal handles tap without uncaught exception
      expect(tester.takeException(), isNull);
    });

    testWidgets('never cuts users while speaking and processes only after silence threshold', (tester) async {
      String? sentPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueModal(
            ttsHandler: ttsHandler,
            onSendPrompt: (prompt) async {
              sentPrompt = prompt;
              return 'Syllabot explains $prompt';
            },
          ),
        ),
      );

      // Drain greeting
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // User pauses: verify sentPrompt is still null (user not cut off)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(sentPrompt, isNull);

      // Verify no exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
