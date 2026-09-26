import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/profile/presentation/widgets/study_statistics_summary_card.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget createTestWidget({required Size screenSize}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: const SingleChildScrollView(
              child: StudyStatisticsSummaryCard(
                profile: UserProfileEntity(
                  id: 'user_123',
                  email: 'test@example.com',
                  displayName: 'Test User',
                  xpPoints: 685,
                  streakDays: 2,
                  retentionBenchmark: 0.47,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('StudyStatisticsSummaryCard Widget Tests', () {
    testWidgets('renders statistics tiles without layout overflow on narrow 360px viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(screenSize: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(find.text('Study Analytics Summary'), findsOneWidget);
      expect(find.text('Study Hours'), findsOneWidget);
      expect(find.text('Cards Mastered'), findsOneWidget);
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('Retention Rate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders statistics tiles without layout overflow on 320px ultra-compact viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(screenSize: const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(find.text('Study Analytics Summary'), findsOneWidget);
      expect(find.text('Retention Rate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
