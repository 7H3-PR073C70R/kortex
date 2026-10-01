import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import '../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MediaUploadService.clearCacheForTesting);

  group('VoiceNotePlayerWidget', () {
    testWidgets('renders play button and duration', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test1.m4a',
            durationSeconds: 42,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Voice Note'), findsOneWidget);
      expect(find.text('00:00 / 00:42'), findsOneWidget);
    });

    testWidgets('does not show transcript toggle when showTranscript is false',
        (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test2.m4a',
            durationSeconds: 15,
            showTranscript: false,
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
            audioUrl: 'https://example.com/test3.m4a',
            durationSeconds: 10,
            transcript: realTranscript,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show Speech-to-Text 📝'), findsOneWidget);

      await tester.tap(find.text('Show Speech-to-Text 📝'));
      await tester.pumpAndSettle();

      expect(find.text(realTranscript), findsOneWidget);
      expect(find.text('Hide Transcript'), findsOneWidget);
    });

    testWidgets(
        'clicking transcript toggle when no transcript is provided triggers onTranscribe and displays result',
        (tester) async {
      const generatedTranscript =
          'This is an AI generated transcript from Whisper';
      var transcribeCalled = false;
      String? loadedTranscript;

      await tester.pumpApp(
        Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test4.m4a',
            durationSeconds: 10,
            replyId: 'reply-123',
            onTranscriptLoaded: (val) {
              loadedTranscript = val;
            },
            onTranscribe: ({required audioUrl, replyId, postId}) async {
              transcribeCalled = true;
              expect(audioUrl, 'https://example.com/test4.m4a');
              expect(replyId, 'reply-123');
              return generatedTranscript;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show Speech-to-Text 📝'), findsOneWidget);
      await tester.tap(find.text('Show Speech-to-Text 📝'));
      await tester.pumpAndSettle();

      expect(transcribeCalled, isTrue);
      expect(loadedTranscript, generatedTranscript);
      expect(find.text(generatedTranscript), findsOneWidget);
      expect(find.text('Hide Transcript'), findsOneWidget);
    });

    testWidgets(
        'uses cached transcript immediately and does not call onTranscribe again',
        (tester) async {
      const cachedText = 'Previously transcribed text saved in cache';
      MediaUploadService.cacheTranscript(
        audioUrl: 'https://example.com/test-cached.m4a',
        transcript: cachedText,
      );

      var transcribeCalled = false;

      await tester.pumpApp(
        Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test-cached.m4a',
            durationSeconds: 10,
            onTranscribe: ({required audioUrl, replyId, postId}) async {
              transcribeCalled = true;
              return 'Should not be called';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show Speech-to-Text 📝'), findsOneWidget);
      await tester.tap(find.text('Show Speech-to-Text 📝'));
      await tester.pumpAndSettle();

      // Verified: onTranscribe was NOT called because cache was hit!
      expect(transcribeCalled, isFalse);
      expect(find.text(cachedText), findsOneWidget);
      expect(find.text('Hide Transcript'), findsOneWidget);
    });

    testWidgets('triggers onDelete callback when delete button is pressed',
        (tester) async {
      var deleted = false;
      await tester.pumpApp(
        Scaffold(
          body: VoiceNotePlayerWidget(
            audioUrl: 'https://example.com/test5.m4a',
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
