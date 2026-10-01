import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';

import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceNoteRecorderWidget Tests', () {
    testWidgets('Renders hold to record mic icon initially in idle state',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceNoteRecorderWidget(
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

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.text('Drag up to lock 🔒'), findsNothing);
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('Renders compact mode mic icon correctly', (tester) async {
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
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.mic_none_rounded));
      expect(icon.size, equals(18));
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
      expect(find.text('Drag up to lock 🔒'), findsOneWidget);
      expect(find.text('Testing live STT auto-fill'), findsOneWidget);
      expect(find.byType(AudioWaveformVisualizer), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Renders VoiceRecordingBannerWidget locked state correctly',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: VoiceRecordingBannerWidget(
            isLocked: true,
            durationSeconds: 45,
            onCancel: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('Locked 🔒'), findsOneWidget);
    });
  });
}
