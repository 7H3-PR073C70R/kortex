import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/study_activity_heatmap.dart';
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
  group('StudyActivityHeatmap Widget Test Suite', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final activityMap = <DateTime, int>{
      today: 15,
      yesterday: 8,
    };

    testWidgets('renders heatmap title, review counter, and legend',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          StudyActivityHeatmap(activityData: activityMap),
        ),
      );

      expect(find.text('Study Activity & Consistency'), findsOneWidget);
      expect(find.text('23 Reviews this Year'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });
  });
}
