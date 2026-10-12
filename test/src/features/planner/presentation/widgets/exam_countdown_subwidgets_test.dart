import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/widgets/countdown/active_milestone_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/countdown/untracked_milestone_card.dart';
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
  final sampleExam = ExamEventEntity(
    id: 'exam-cbt-101',
    userId: 'usr-1',
    examName: 'JAMB CBT 2026',
    targetDate: DateTime.now().add(const Duration(days: 10)),
    subjectTrack: 'JAMB',
    assessmentType: AssessmentType.mockExam,
    scopedTopics: const ['English', 'Mathematics'],
    totalCardsCount: 100,
    dailyTarget: 10,
  );

  group('Countdown Subwidgets Test Suite', () {
    testWidgets('UntrackedMilestoneCard renders headline and target milestone', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          UntrackedMilestoneCard(targetExam: sampleExam),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track Assessment Milestone'), findsOneWidget);
      expect(find.byIcon(Icons.access_alarm_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('ActiveMilestoneCard renders full header, readiness, topics and responds to CTA', (tester) async {
      var ctaPressed = false;
      const readinessResult = CbtReadinessResult(
        scorePercent: 88,
        statusLabel: 'Exam Ready',
        statusColor: Color(0xFF10B981),
        syllabusCoverage: 0.9,
        fsrsRetentionRate: 0.86,
        mockScoreRatio: 0.88,
        projectedGrade: 'A',
        projectedScoreRange: '280 - 310',
      );

      await tester.pumpWidget(
        createTestApp(
          ActiveMilestoneCard(
            exam: sampleExam,
            pace: 12,
            badgeColor: const Color(0xFF10B981),
            isTopPriority: true,
            readinessResult: readinessResult,
            countdownHeadline: 'JAMB CBT 2026 • 10 days left',
            actionLabel: 'Launch Mock Exam',
            onPrimaryAction: () {
              ctaPressed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('MOCK EXAM'), findsOneWidget);
      expect(find.textContaining('JAMB Track'), findsOneWidget);
      expect(find.text('Readiness: 88%'), findsOneWidget);
      expect(find.text('Top Priority'), findsOneWidget);
      expect(find.text('JAMB CBT 2026 • 10 days left'), findsOneWidget);
      expect(find.textContaining('English • Mathematics'), findsOneWidget);
      expect(find.text('Launch Mock Exam'), findsOneWidget);

      await tester.tap(find.text('Launch Mock Exam'));
      await tester.pumpAndSettle();
      expect(ctaPressed, isTrue);
    });
  });
}
