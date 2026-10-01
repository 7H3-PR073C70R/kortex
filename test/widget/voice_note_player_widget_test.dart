import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import '../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceNotePlayerWidget', () {
    testWidgets('renders play button and duration', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test.m4a',
            durationSeconds: 42,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Voice Note'), findsOneWidget);
      expect(find.text('00:00 / 00:42'), findsOneWidget);
    });

    testWidgets('does not show transcript toggle when transcript is null or empty',
        (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test.m4a',
            durationSeconds: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Speech-to-Text'), findsNothing);
    });

    testWidgets(
        'shows transcript toggle and expands real transcript when provided',
        (tester) async {
      const realTranscript = 'Newton second law states that F equals m a';
      await tester.pumpApp(
        const Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test.m4a',
            durationSeconds: 10,
            transcript: realTranscript,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Show Speech-to-Text (STT)'), findsOneWidget);

      await tester.tap(find.textContaining('Show Speech-to-Text (STT)'));
      await tester.pumpAndSettle();

      expect(find.text(realTranscript), findsOneWidget);
      expect(find.textContaining('Hide Speech-to-Text'), findsOneWidget);
    });

    testWidgets('triggers onDelete callback when delete button is pressed',
        (tester) async {
      var deleted = false;
      await tester.pumpApp(
        Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test.m4a',
            onDelete: () {
              deleted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });
  });
}
