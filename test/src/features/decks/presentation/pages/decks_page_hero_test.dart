import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/pages/decks_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksBloc extends Mock implements DecksBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDecksBloc bloc;

  setUp(() {
    bloc = MockDecksBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream<DecksState>.empty());
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpDecksHome(
    WidgetTester tester,
    List<DeckEntity> decks, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(
      () => bloc.state,
    ).thenReturn(
      DecksState(
        status: DecksStatus.loaded,
        allDecks: decks,
        filteredDecks: decks,
      ),
    );
    locator.registerSingleton<DecksBloc>(bloc);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DecksPage(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // The empty-state mascot breathes on a looping ticker, so a full
      // settle would never finish — advance past the entrance instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  group('Decks home Today hero', () {
    testWidgets('presents one dominant CTA when cards are due', (
      tester,
    ) async {
      const deck = DeckEntity(
        id: 'hero_deck_due',
        title: 'Pharmacology',
        subject: 'PHAR',
        totalCards: 60,
        dueCards: 5,
        masteryRate: 0.4,
        category: 'Core',
      );

      await pumpDecksHome(tester, const [deck]);

      expect(find.text('5 cards are waiting'), findsOneWidget);
      expect(find.textContaining('Review 5 due cards'), findsWidgets);
      expect(find.text('All caught up'), findsNothing);
    });

    testWidgets('switches to the calm variant when nothing is due', (
      tester,
    ) async {
      const deck = DeckEntity(
        id: 'hero_deck_calm',
        title: 'Pharmacology',
        subject: 'PHAR',
        totalCards: 60,
        dueCards: 0,
        masteryRate: 0.9,
        category: 'Core',
      );

      await pumpDecksHome(tester, const [deck]);

      expect(find.text('All caught up'), findsOneWidget);
      expect(
        find.text('Nothing due right now — take the win.'),
        findsOneWidget,
      );
      expect(find.textContaining('Review'), findsNothing);
    });

    testWidgets('hero is hidden entirely before any deck exists', (
      tester,
    ) async {
      await pumpDecksHome(tester, const [], settle: false);

      expect(find.text('All caught up'), findsNothing);
      expect(find.textContaining('cards are waiting'), findsNothing);

      // Unmount so the mascot's looping ticker is released before teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
