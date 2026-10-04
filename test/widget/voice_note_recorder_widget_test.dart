import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/pump_app.dart';

class MockAudioRecordingService extends Mock
    implements AudioRecordingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioRecordingService mockRecordingService;

  setUp(() async {
    mockRecordingService = MockAudioRecordingService();
    when(() => mockRecordingService.amplitudeStream)
        .thenAnswer((_) => const Stream<double>.empty());
    when(() => mockRecordingService.hasPermission())
        .thenAnswer((_) async => true);
    when(() => mockRecordingService.isRecording())
        .thenAnswer((_) async => false);

    if (GetIt.I.isRegistered<AudioRecordingService>()) {
      await GetIt.I.unregister<AudioRecordingService>();
    }
    GetIt.I.registerSingleton<AudioRecordingService>(mockRecordingService);
  });

  tearDown(() async {
    if (GetIt.I.isRegistered<AudioRecordingService>()) {
      await GetIt.I.unregister<AudioRecordingService>();
    }
  });

  group('VoiceRecordingBannerWidget', () {
    testWidgets('renders duration, waveform, and buttons properly',
        (tester) async {
      var doneCalled = false;
      var cancelCalled = false;

      await tester.pumpApp(
        Scaffold(
          body: VoiceRecordingBannerWidget(
            isLocked: true,
            durationSeconds: 14,
            transcriptText: 'Discussing projectile motion formula',
            onCancel: () {
              cancelCalled = true;
            },
            onDone: () {
              doneCalled = true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('00:14'), findsOneWidget);
      expect(find.text('Locked 🔒'), findsOneWidget);
      expect(find.text('Discussing projectile motion formula'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(doneCalled, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(cancelCalled, isTrue);
    });
  });

  group('VoiceNoteRecorderWidget', () {
    testWidgets('renders compact mic icon in idle state', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceNoteRecorderWidget(
            compact: true,
            onRecordingComplete: ({
              required audioUrl,
              required durationSeconds,
              required transcript,
            }) {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('VoiceNoteRecorderController attaches and triggers finish',
        (tester) async {
      final controller = VoiceNoteRecorderController();

      var completeAudioUrl = '';
      when(() => mockRecordingService.stopRecording())
          .thenAnswer((_) async => null);

      await tester.pumpApp(
        Scaffold(
          body: VoiceNoteRecorderWidget(
            recorderController: controller,
            onRecordingComplete: ({
              required audioUrl,
              required durationSeconds,
              required transcript,
            }) {
              completeAudioUrl = audioUrl;
            },
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await controller.finish();
      await tester.pump(const Duration(milliseconds: 100));

      expect(completeAudioUrl, isEmpty);
    });
  });
}
