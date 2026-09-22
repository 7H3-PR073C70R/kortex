import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksBloc extends Mock implements DecksBloc {}

Widget _buildTestApp(Widget child, DecksBloc bloc) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<DecksBloc>.value(
      value: bloc,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deck = DeckEntity(
    id: 'deck_overflow_1',
    title: 'Organic Chemistry',
    subject: 'CHEM',
    totalCards: 42,
    dueCards: 7,
    masteryRate: 0.35,
    category: 'Recall',
  );

  late MockDecksBloc bloc;

  setUp(() {
    bloc = MockDecksBloc();
    when(
      () => bloc.state,
    ).thenReturn(
      const DecksState(
        status: DecksStatus.loaded,
        allDecks: [deck],
        filteredDecks: [deck],
      ),
    );
    when(() => bloc.stream).thenAnswer((_) => const Stream<DecksState>.empty());
    registerFallbackValue(const DecksStarted());
  });

  Future<void> pumpTile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(const DeckListTileCard(deck: deck), bloc),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('card body carries no inline destructive action', (tester) async {
    await pumpTile(tester);

    // Due signal is on the face of the tile; delete is not.
    expect(find.text('7'), findsOneWidget);
    expect(find.text('due'), findsOneWidget);
    expect(find.text('Delete deck'), findsNothing);
  });

  testWidgets(
    'delete lives behind the overflow menu and keeps its confirmation',
    (tester) async {
      await pumpTile(tester);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Deck details'), findsOneWidget);
      expect(find.text('Delete deck'), findsOneWidget);

      await tester.tap(find.text('Delete deck'));
      await tester.pumpAndSettle();

      // Menu selection only opens the confirm dialog — nothing deleted yet.
      expect(find.text('Delete Study Deck'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<DecksDeckDeleted>())));

      await tester.tap(find.text('Delete Deck'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(any(that: isA<DecksDeckDeleted>()))).called(1);

      // Drain the success snackbar timer so no pending Timer leaks.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('cancelling the confirmation never deletes the deck', (
    tester,
  ) async {
    await pumpTile(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete deck'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any(that: isA<DecksDeckDeleted>())));
  });
}
