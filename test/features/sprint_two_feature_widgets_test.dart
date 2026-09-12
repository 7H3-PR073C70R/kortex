import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/audio_pronounce_button.dart';
import 'package:kortex/src/features/decks/presentation/widgets/image_occlusion_card_viewer.dart';
import 'package:kortex/src/features/decks/presentation/widgets/subdeck_hierarchy_tree.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/audio_lecture_ingestion_sheet.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/promo_code_bottom_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/syllabus_checklist_widget.dart';
import 'package:kortex/src/features/profile/presentation/widgets/active_sessions_list_widget.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/flag_question_bottom_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_audio_reader_button.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_latex_scratchpad_widget.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Sprint 2 & Feature Gap Widget Test Suite', () {
    testWidgets('SubdeckHierarchyTree builds tree hierarchy and selects deck', (
      tester,
    ) async {
      final decks = [
        const DeckEntity(
          id: 'deck-1',
          title: 'Physics::Thermodynamics::CarnotEngine',
          subject: 'Physics',
          category: 'STEM',
          description: 'Carnot cycles',
          totalCards: 15,
          dueCards: 5,
          masteryRate: 0.8,
        ),
        const DeckEntity(
          id: 'deck-2',
          title: 'Biology::Genetics',
          subject: 'Biology',
          category: 'STEM',
          description: 'Mendelian genetics',
          totalCards: 20,
          dueCards: 2,
          masteryRate: 0.9,
        ),
      ];

      DeckEntity? selectedDeck;

      await tester.pumpWidget(
        _wrapWithTheme(
          SubdeckHierarchyTree(
            decks: decks,
            onDeckSelected: (d) => selectedDeck = d,
          ),
        ),
      );

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Genetics'), findsOneWidget);

      await tester.tap(find.text('Genetics'));
      await tester.pumpAndSettle();

      expect(selectedDeck?.id, equals('deck-2'));
    });

    testWidgets('AudioPronounceButton renders with volume icon and responds to tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AudioPronounceButton(
            textToPronounce: 'Photosynthesis',
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byType(AudioPronounceButton));
      await tester.pumpAndSettle();
    });

    testWidgets('ImageOcclusionCardViewer renders masks and toggles reveal state', (
      tester,
    ) async {
      const masks = [
        OcclusionMask(
          id: 'm1',
          rect: Rect.fromLTWH(0.1, 0.1, 0.3, 0.2),
          answerText: 'Left Ventricle',
        ),
      ];

      String? revealedId;

      await tester.pumpWidget(
        _wrapWithTheme(
          ImageOcclusionCardViewer(
            masks: masks,
            onMaskRevealed: (id) => revealedId = id,
          ),
        ),
      );

      expect(find.text('Pinch to Zoom • Tap Mask to Reveal'), findsOneWidget);
      expect(find.text('Reveal All'), findsOneWidget);

      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();

      expect(revealedId, equals('m1'));
      expect(find.text('Left Ventricle'), findsOneWidget);
    });

    testWidgets('AudioLectureIngestionSheet renders and triggers chunked progress', (
      tester,
    ) async {
      String? transcribed;

      await tester.pumpWidget(
        _wrapWithTheme(
          AudioLectureIngestionSheet(
            onTranscriptionCompleted: (t) => transcribed = t,
          ),
        ),
      );

      expect(find.text('Audio Lecture Ingestion'), findsOneWidget);
      expect(find.text('Start Transcription'), findsOneWidget);

      await tester.tap(find.text('Start Transcription'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(transcribed, isNotNull);
      expect(find.text('Generate Flashcards from Lecture'), findsOneWidget);
    });

    testWidgets('ChatLatexScratchpadWidget renders drawing canvas and inserts LaTeX', (
      tester,
    ) async {
      String? inserted;

      await tester.pumpWidget(
        _wrapWithTheme(
          ChatLatexScratchpadWidget(
            onInsertLatex: (val) => inserted = val,
          ),
        ),
      );

      expect(find.text('Math Formula Scratchpad'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.tap(find.text('Insert Formula into Chat'));
      await tester.pumpAndSettle();

      expect(inserted, contains(r'\int'));
    });

    testWidgets('FlagQuestionBottomSheet renders reasons and submits report', (
      tester,
    ) async {
      String? reportedId;
      FlagQuestionReason? reportedReason;

      await tester.pumpWidget(
        _wrapWithTheme(
          FlagQuestionBottomSheet(
            questionId: 'q-101',
            questionSnippet: 'What is the speed of light?',
            onSubmitReport: (id, reason, _) {
              reportedId = id;
              reportedReason = reason;
            },
          ),
        ),
      );

      expect(find.text('Report Question Issue'), findsOneWidget);
      expect(find.text('Typographical error in question text'), findsOneWidget);

      await tester.tap(find.text('Typographical error in question text'));
      await tester.pumpAndSettle();

      final submitFinder = find.text('Submit Quality Report');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(reportedId, equals('q-101'));
      expect(reportedReason, equals(FlagQuestionReason.typo));
    });

    testWidgets('QuizAudioReaderButton renders and builds script', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const QuizAudioReaderButton(
            questionText: 'What is H2O?',
            options: ['Water', 'Helium', 'Hydrogen', 'Oxygen'],
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byType(QuizAudioReaderButton));
      await tester.pumpAndSettle();
    });

    testWidgets('SyllabusChecklistWidget filters subjects and toggles topic mastery', (
      tester,
    ) async {
      const topics = [
        SyllabusTopic(
          id: 't1',
          title: 'Newtonian Mechanics',
          subject: 'Physics',
          weightPercent: 25,
        ),
        SyllabusTopic(
          id: 't2',
          title: 'Organic Chemistry',
          subject: 'Chemistry',
          weightPercent: 30,
        ),
      ];

      SyllabusTopic? toggledTopic;
      bool? isMasteredResult;

      await tester.pumpWidget(
        _wrapWithTheme(
          SyllabusChecklistWidget(
            topics: topics,
            onTopicToggled: (t, {required isMastered}) {
              toggledTopic = t;
              isMasteredResult = isMastered;
            },
          ),
        ),
      );

      expect(find.text('Syllabus Topic Mastery'), findsOneWidget);
      expect(find.text('Newtonian Mechanics'), findsOneWidget);
      expect(find.text('Organic Chemistry'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(toggledTopic?.id, equals('t1'));
      expect(isMasteredResult, isTrue);
    });

    testWidgets('ActiveSessionsListWidget renders sessions and revokes session', (
      tester,
    ) async {
      final sessions = [
        DeviceSession(
          id: 's1',
          deviceName: 'iPhone 15 Pro',
          osType: 'ios',
          ipAddress: '192.168.1.10',
          location: 'Lagos, Nigeria',
          lastActive: DateTime.now(),
          isCurrentDevice: true,
        ),
        DeviceSession(
          id: 's2',
          deviceName: 'MacBook Air M2',
          osType: 'macos',
          ipAddress: '192.168.1.15',
          location: 'Lagos, Nigeria',
          lastActive: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      String? revokedId;

      await tester.pumpWidget(
        _wrapWithTheme(
          ActiveSessionsListWidget(
            sessions: sessions,
            onRevokeSession: (id) => revokedId = id,
          ),
        ),
      );

      expect(find.text('Active Logins (2)'), findsOneWidget);
      expect(find.text('This Device'), findsOneWidget);
      expect(find.text('MacBook Air M2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      expect(revokedId, equals('s2'));
    });

    testWidgets('PromoCodeBottomSheet enters and redeems access code', (
      tester,
    ) async {
      String? redeemed;

      await tester.pumpWidget(
        _wrapWithTheme(
          PromoCodeBottomSheet(
            onCodeRedeemed: (c) => redeemed = c,
          ),
        ),
      );

      expect(find.text('Redeem Voucher / Promo Code'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'SCHOLAR_PRO');
      await tester.tap(find.text('Redeem Access Code'));
      await tester.pumpAndSettle();

      expect(redeemed, equals('SCHOLAR_PRO'));
      expect(find.text('Successfully redeemed! Kortex Pro features unlocked.'), findsOneWidget);
    });
  });
}
