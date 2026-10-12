import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_ai_hint_banner.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_deck_completed_view.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_deck_picker_view.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_fsrs_rating_bar.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_interactive_flashcard.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_top_study_hud.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  const sampleCard = FlashcardEntity(
    id: 'card-1',
    deckId: 'deck-100',
    front: 'What is the Schrödinger equation?',
    back: 'A linear partial differential equation describing quantum wavefunctions.',
  );

  group('Study Room Workspace Sub-Widgets Unit & Widget Tests', () {
    testWidgets('WorkspaceTopStudyHud renders title, progress, and triggers onSwitchDeckTap',
        (tester) async {
      var switchTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          WorkspaceTopStudyHud(
            deckTitle: 'Quantum Mechanics',
            currentIndex: 0,
            totalCards: 10,
            onSwitchDeckTap: () => switchTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Quantum Mechanics'), findsOneWidget);
      expect(find.text('1/10'), findsOneWidget);
      expect(find.text('Decks'), findsOneWidget);

      await tester.tap(find.text('Decks'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(switchTapped, isTrue);
    });

    testWidgets('WorkspaceInteractiveFlashcard renders question and triggers onFlipTap',
        (tester) async {
      var flipTapped = false;
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      final animation = Tween<double>(begin: 0, end: 1).animate(controller);

      await tester.pumpWidget(
        createTestWidget(
          SizedBox(
            height: 400,
            child: WorkspaceInteractiveFlashcard(
              card: sampleCard,
              flipAnimation: animation,
              onFlipTap: () => flipTapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('QUESTION / PROMPT'), findsOneWidget);
      expect(find.text('Tap to flip'), findsOneWidget);

      await tester.tap(find.byType(WorkspaceInteractiveFlashcard));
      await tester.pump(const Duration(milliseconds: 100));
      expect(flipTapped, isTrue);
    });

    testWidgets('WorkspaceAiHintBanner renders prompt and triggers onGetHintTap',
        (tester) async {
      var getHintTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          WorkspaceAiHintBanner(
            activeAiHint: null,
            isLoadingHint: false,
            onGetHintTap: () => getHintTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Stuck on this concept? Syllabot AI can help.'),
        findsOneWidget,
      );
      expect(find.text('Get Hint'), findsOneWidget);

      await tester.tap(find.text('Get Hint'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(getHintTapped, isTrue);
    });

    testWidgets('WorkspaceAiHintBanner renders active thought-starter hint',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          WorkspaceAiHintBanner(
            activeAiHint: '💡 Thought starter: Think about wave-particle duality.',
            isLoadingHint: false,
            onGetHintTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('💡 Thought starter: Think about wave-particle duality.'),
        findsOneWidget,
      );
    });

    testWidgets('WorkspaceFsrsRatingBar renders grades and triggers onRateCard',
        (tester) async {
      int? selectedGrade;
      await tester.pumpWidget(
        createTestWidget(
          WorkspaceFsrsRatingBar(
            onRateCard: (grade) => selectedGrade = grade,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);

      await tester.tap(find.text('Good'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(selectedGrade, equals(3));

      await tester.tap(find.text('Easy'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(selectedGrade, equals(4));
    });

    testWidgets('WorkspaceDeckCompletedView renders trophy and triggers action buttons',
        (tester) async {
      var reviewAgainTapped = false;
      var switchDeckTapped = false;

      await tester.pumpWidget(
        createTestWidget(
          WorkspaceDeckCompletedView(
            deckTitle: 'Quantum Mechanics',
            totalCards: 15,
            onReviewAgainTap: () => reviewAgainTapped = true,
            onSwitchDeckTap: () => switchDeckTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Deck Round Complete! 🎉'), findsOneWidget);
      expect(
        find.text('You reviewed all 15 cards in "Quantum Mechanics" alongside your pod.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Review Again'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(reviewAgainTapped, isTrue);

      await tester.tap(find.text('Switch Deck'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(switchDeckTapped, isTrue);
    });

    testWidgets('WorkspaceDeckPickerView renders header and empty state gracefully',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          SizedBox(
            height: 600,
            child: WorkspaceDeckPickerView(
              onDeckSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Choose a Deck to Study'), findsOneWidget);
      expect(find.text('No decks available yet'), findsOneWidget);
    });
  });
}
