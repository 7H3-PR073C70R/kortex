import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_action_dock.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_header.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_modal_body.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_response_viewer.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_status_headline.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_transcript_card.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_sound_ribbon_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

class _FakeTtsService implements TextToSpeechService {
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
  @override
  bool get isSpeaking => false;
  @override
  VoiceGender get voiceGender => VoiceGender.female;
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
  List<String> get availableKokoroVoices => ['Bella'];

  @override
  Future<void> speak(String rawText) async {}
  @override
  Future<void> enqueueSentence(String rawSentence) async {}
  @override
  Future<void> waitForQueueDrained() async {}
  @override
  Future<void> stop() async {}
  @override
  void clearQueue() {}
  @override
  Future<void> setVoiceGender(VoiceGender gender) async {}
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

  late TextToSpeechHandler ttsHandler;

  setUp(() {
    ttsHandler = TextToSpeechHandler(ttsService: _FakeTtsService());
  });

  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('Voice Dialogue Sub-Widgets Test Suite', () {
    testWidgets('VoiceDialogueHeader displays title and handles clicks', (tester) async {
      var genderToggled = false;
      var closed = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueHeader(
            engineType: ExecutionEngineType.cloudRemote,
            initialMode: SocraticMode.stepByStep,
            selectedGender: VoiceGender.female,
            isDesktop: true,
            onToggleGender: () => genderToggled = true,
            onCloseModal: () => closed = true,
          ),
        ),
      );

      expect(find.text('Syllabot Voice'), findsOneWidget);
      expect(find.text('Step-by-Step Proof'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(closed, isTrue);

      await tester.tap(find.text('Female Voice'));
      expect(genderToggled, isTrue);
    });

    testWidgets('VoiceDialogueStatusHeadline renders correct texts per state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const VoiceDialogueStatusHeadline(
            state: DialogueState.listening,
            liveTranscript: 'Hello Syllabot',
          ),
        ),
      );
      expect(find.byType(VoiceDialogueStatusHeadline), findsOneWidget);

      await tester.pumpWidget(
        buildTestWidget(
          child: const VoiceDialogueStatusHeadline(
            state: DialogueState.thinking,
            liveTranscript: '',
          ),
        ),
      );
      expect(find.textContaining('analyzing'), findsOneWidget);
    });

    testWidgets('VoiceDialogueTranscriptCard toggles expansion', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueTranscriptCard(
            liveTranscript: 'Explain gravity',
            isTranscriptExpanded: false,
            state: DialogueState.listening,
            onToggleExpanded: () => toggled = true,
          ),
        ),
      );

      expect(find.text('Show Speech-to-Text (STT) 📝'), findsOneWidget);
      expect(find.text('"Explain gravity"'), findsNothing);

      await tester.tap(find.text('Show Speech-to-Text (STT) 📝'));
      expect(toggled, isTrue);

      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueTranscriptCard(
            liveTranscript: 'Explain gravity',
            isTranscriptExpanded: true,
            state: DialogueState.listening,
            onToggleExpanded: () {},
          ),
        ),
      );

      expect(find.text('Hide Speech-to-Text 📝'), findsOneWidget);
      expect(find.text('"Explain gravity"'), findsOneWidget);
    });

    testWidgets('VoiceDialogueActionDock toggles mute and interactions', (tester) async {
      var muteTapped = false;
      var interactionTapped = false;
      var closeTapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceDialogueActionDock(
            stateColor: Colors.blue,
            isDesktop: false,
            state: DialogueState.idle,
            isMuted: false,
            liveTranscript: '',
            onToggleMute: () => muteTapped = true,
            onInteractionTap: () => interactionTapped = true,
            onCloseModal: () => closeTapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      expect(muteTapped, isTrue);

      await tester.tap(find.byIcon(Icons.mic_rounded));
      expect(interactionTapped, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      expect(closeTapped, isTrue);
    });

    testWidgets('VoiceDialogueResponseViewer renders response bubble', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: SizedBox(
            height: 300,
            child: VoiceDialogueResponseViewer(
              latestResponse: 'Here is the explanation.',
              engineType: ExecutionEngineType.cloudRemote,
              ttsHandler: ttsHandler,
              isDesktop: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Here is the explanation.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('VoiceSoundRibbonWidget paints smoothly', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      final soundLevel = ValueNotifier<double>(0.5);

      await tester.pumpWidget(
        buildTestWidget(
          child: VoiceSoundRibbonWidget(
            stateColor: Colors.blue,
            state: DialogueState.speaking,
            soundLevelNotifier: soundLevel,
            animation: controller,
            height: 100,
          ),
        ),
      );

      expect(find.byType(VoiceSoundRibbonWidget), findsOneWidget);
      controller.dispose();
      soundLevel.dispose();
    });

    testWidgets('VoiceDialogueModalBody renders combined layout', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      final soundLevel = ValueNotifier<double>(0.5);

      await tester.pumpWidget(
        buildTestWidget(
          child: SizedBox(
            height: 700,
            width: 400,
            child: VoiceDialogueModalBody(
              engineType: ExecutionEngineType.cloudRemote,
              initialMode: SocraticMode.stepByStep,
              selectedGender: VoiceGender.female,
              isDesktop: false,
              isLandscape: false,
              isCompact: false,
              stateColor: Colors.blue,
              state: DialogueState.idle,
              soundLevelNotifier: soundLevel,
              ribbonAnimationController: controller,
              liveTranscript: '',
              latestResponse: '',
              ttsHandler: ttsHandler,
              isTranscriptExpanded: false,
              isMuted: false,
              onToggleGender: () {},
              onCloseModal: () {},
              onInteractionTap: () {},
              onToggleTranscriptExpanded: () {},
              onToggleMute: () {},
            ),
          ),
        ),
      );

      expect(find.text('Syllabot Voice'), findsOneWidget);
      expect(find.byType(VoiceDialogueActionDock), findsOneWidget);

      controller.dispose();
      soundLevel.dispose();
    });
  });
}
