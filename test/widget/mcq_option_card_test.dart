import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('McqOptionCard Widget Test Suite', () {
    testWidgets('renders option prefix and text', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: r'\Delta G = \Delta H - T\Delta S',
            index: 0, // Option A
            isSelected: false,
            isAnswered: false,
            isCorrect: false,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text(r'\Delta G = \Delta H - T\Delta S'), findsOneWidget);

      await tester.tap(find.byType(McqOptionCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders check icon when answered and correct', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Correct Answer',
            index: 1, // Option B
            isSelected: true,
            isAnswered: true,
            isCorrect: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders cancel icon when answered and incorrect',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Wrong Answer',
            index: 2, // Option C
            isSelected: true,
            isAnswered: true,
            isCorrect: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });
  });
}
