import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/scheduler_toggle_tile.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('SchedulerToggleTile Widget Test Suite', () {
    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets(
      'renders current SM-2 state and triggers switch to FSRS on tap',
      (tester) async {
        SpacedRepetitionAlgorithm? selected;

        await tester.pumpWidget(
          createTestApp(
            SchedulerToggleTile(
              currentAlgorithm: SpacedRepetitionAlgorithm.sm2,
              onChanged: (alg) {
                selected = alg;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Spaced Repetition Scheduler'), findsOneWidget);
        expect(find.text('SM-2'), findsOneWidget);
        expect(find.text('FSRS-4.5'), findsOneWidget);
        expect(
          find.text('Classical SuperMemo-2 interval and ease factor spacing'),
          findsOneWidget,
        );

        await tester.tap(find.text('FSRS-4.5'));
        await tester.pump();

        expect(selected, equals(SpacedRepetitionAlgorithm.fsrs));
      },
    );
  });
}
