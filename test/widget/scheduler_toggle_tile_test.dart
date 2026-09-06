import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/scheduler_toggle_tile.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('SchedulerToggleTile Widget Test Suite', () {
    Widget createTestApp(Widget child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
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
      'renders FSRS-6 active neural engine status',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            SchedulerToggleTile(
              currentAlgorithm: SpacedRepetitionAlgorithm.fsrs,
              onChanged: (_) {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Spaced Repetition Scheduler'), findsOneWidget);
        expect(find.text('FSRS-6'), findsOneWidget);
        expect(
          find.textContaining('Adaptive 21-parameter neural scheduling'),
          findsOneWidget,
        );
      },
    );
  });
}
