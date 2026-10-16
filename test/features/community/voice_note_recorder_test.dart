import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class MockAudioRecordingService extends Mock
    implements AudioRecordingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioRecordingService mockRecordingService;

  setUp(() {
    mockRecordingService = MockAudioRecordingService();
    when(() => mockRecordingService.amplitudeStream)
        .thenAnswer((_) => const Stream<double>.empty());
    when(() => mockRecordingService.hasPermission())
        .thenAnswer((_) async => true);
    when(() => mockRecordingService.isRecording())
        .thenAnswer((_) async => false);
  });

  group('VoiceNoteRecorderWidget Tests', () {
    testWidgets('Renders mic icon initially in idle state', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceNoteRecorderWidget(
            audioRecordingService: mockRecordingService,
            onRecordingComplete: ({
              required audioUrl,
              required durationSeconds,
              required transcript,
            }) {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('REC'), findsNothing);
    });

    testWidgets('Renders compact mode mic icon correctly', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceNoteRecorderWidget(
            audioRecordingService: mockRecordingService,
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
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.mic_rounded));
      expect(icon.size, equals(19));
    });

    testWidgets('Renders VoiceRecordingBannerWidget with waveform and status correctly',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceRecordingBannerWidget(
            durationSeconds: 12,
            transcriptText: 'Testing live STT auto-fill',
            onCancel: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:12'), findsOneWidget);
      expect(find.text('REC'), findsOneWidget);
      expect(find.byType(AudioWaveformVisualizer), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('Renders VoiceRecordingBannerWidget with expand transcript button',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceRecordingBannerWidget(
            durationSeconds: 45,
            transcriptText: 'Discussing quantum superposition',
            onCancel: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('REC'), findsOneWidget);
      expect(find.text('Show Live STT Preview 📝'), findsOneWidget);

      await tester.tap(find.text('Show Live STT Preview 📝'));
      await tester.pump();

      expect(find.text('Discussing quantum superposition'), findsOneWidget);
    });
  });
}
