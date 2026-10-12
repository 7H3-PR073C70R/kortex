import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_auxiliary_banners.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_error_view.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_keyboard_listener.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_rating_dock.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_shimmer_skeleton.dart';
import 'package:kortex/src/l10n/l10n.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('StudySessionShimmerSkeleton Tests', () {
    testWidgets('renders skeleton placeholders without error', (tester) async {
      await tester.pumpWidget(_buildTestApp(const StudySessionShimmerSkeleton()));
      await tester.pump();

      expect(find.byType(StudySessionShimmerSkeleton), findsOneWidget);
    });
  });

  group('StudySessionErrorView Tests', () {
    testWidgets('renders empty state when no flashcards exist', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const StudySessionErrorView(
            errorMessage: 'No cards found in deck',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Flashcards Yet'), findsOneWidget);
      expect(find.text('Generate with AI'), findsOneWidget);
      expect(find.text('Return to Workspace'), findsOneWidget);
    });

    testWidgets('renders error state on generic load error', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const StudySessionErrorView(
            errorMessage: 'Database connection failed',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Session'), findsOneWidget);
      expect(find.text('Database connection failed'), findsOneWidget);
      expect(find.text('Return to Workspace'), findsOneWidget);
    });
  });

  group('StudySessionAuxiliaryBanners Tests', () {
    testWidgets('CramSessionBanner renders days remaining and clamped badge', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const CramSessionBanner(daysUntilExam: 3),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Milestone Crunch: 3 days remaining'), findsOneWidget);
      expect(find.text('Clamped'), findsOneWidget);
    });

    testWidgets('CramSessionBanner renders acute crunch when days <= 1', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const CramSessionBanner(daysUntilExam: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Imminent Assessment Crunch'), findsOneWidget);
    });

    testWidgets('StudyCohortBionicBar displays cohort badge and toggles bionic', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        _buildTestApp(
          StudyCohortBionicBar(
            isBionicEnabled: false,
            onToggleBionic: () => toggled = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Studying with cohort'), findsOneWidget);
      expect(find.text('Bionic Focus'), findsOneWidget);

      await tester.tap(find.text('Bionic Focus'));
      await tester.pump();

      expect(toggled, isTrue);
    });
  });

  group('StudySessionRatingDock Tests', () {
    final sampleCard = FlashcardEntity(
      id: 'card-1',
      deckId: 'deck-1',
      front: 'What is Mitochondria?',
      back: 'The powerhouse of the cell',
      sourceTopic: 'Cell Biology',
    );

    testWidgets('renders swipe hint and Feynman recall trigger when not flipped', (tester) async {
      var flipToggled = false;

      await tester.pumpWidget(
        _buildTestApp(
          StudySessionRatingDock(
            currentCard: sampleCard,
            isFlipped: false,
            intervalPreviews: const {
              FsrsRating.again: 0,
              FsrsRating.hard: 1,
              FsrsRating.good: 3,
              FsrsRating.easy: 7,
            },
            onRateRating: (_) {},
            onToggleFlip: () => flipToggled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Feynman Active Recall'), findsOneWidget);
    });

    testWidgets('renders FSRS rating buttons and cohort bounty when flipped', (tester) async {
      FsrsRating? selectedRating;

      await tester.pumpWidget(
        _buildTestApp(
          StudySessionRatingDock(
            currentCard: sampleCard,
            isFlipped: true,
            intervalPreviews: const {
              FsrsRating.again: 0,
              FsrsRating.hard: 1,
              FsrsRating.good: 3,
              FsrsRating.easy: 7,
            },
            onRateRating: (r) => selectedRating = r,
            onToggleFlip: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stuck on this card? Post Bounty to Cohort'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);

      await tester.tap(find.text('Good'));
      await tester.pump();

      expect(selectedRating, equals(FsrsRating.good));
    });
  });

  group('StudySessionKeyboardListener Tests', () {
    testWidgets('dispatches toggle flip on Space key press', (tester) async {
      var flipToggled = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildTestApp(
          StudySessionKeyboardListener(
            focusNode: focusNode,
            canUndo: true,
            isFlipped: false,
            onUndo: () {},
            onToggleFlip: () => flipToggled = true,
            onSaveCheckpointAndExit: () async {},
            onRateCard: (_) {},
            child: const SizedBox(height: 100, width: 100),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(flipToggled, isTrue);
    });
  });
}
