import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness_gauge_card.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('CBT Readiness Presentation Widgets Test Suite', () {
    const sampleReadinessResult = CbtReadinessResult(
      scorePercent: 78,
      statusLabel: 'On Track',
      projectedGrade: 'A',
      projectedScoreRange: '280 - 310',
      syllabusCoverage: 0.85,
      fsrsRetentionRate: 0.90,
      mockScoreRatio: 0.72,
      remediationSuggestion: 'Focus on Organic Chemistry reactions',
      statusColor: Color(0xFF10B981),
      targetExamType: 'WAEC',
      weakestAreaLabel: 'Organic Chemistry (54%)',
      calibratedCourseCount: 4,
      totalCourseCount: 5,
      subjectBreakdowns: [
        SubjectReadinessBreakdown(
          subjectName: 'Chemistry',
          courseCode: 'CHM 101',
          readinessPercent: 65,
          projectedGrade: 'B',
          coveragePercent: 0.70,
          accuracyPercent: 0.68,
          projectedScore: 68,
          maxScore: 100,
          statusColor: Color(0xFFF59E0B),
        ),
      ],
    );

    testWidgets('CbtReadinessGaugeCard renders score and metric bars correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const CbtReadinessGaugeCard(
            readinessResult: sampleReadinessResult,
            examTitle: 'WASSCE Exam 2026',
            daysRemaining: 42,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('CBT READINESS INDEX'), findsOneWidget);
      expect(find.text('WASSCE Exam 2026'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
      expect(find.text('Syllabus Coverage'), findsOneWidget);
      expect(find.text('Memory Retention'), findsOneWidget);
      expect(find.text('Mock Test Score'), findsOneWidget);
      expect(
        find.text('Focus on Organic Chemistry reactions'),
        findsOneWidget,
      );
    });

    testWidgets('ReadinessMetricBar renders label and percentage', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const ReadinessMetricBar(
            label: 'Retention Rate',
            value: 0.92,
            color: Colors.green,
          ),
        ),
      );

      expect(find.text('Retention Rate'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('ReadinessBreakdownProjectedCard renders score, grade and calibrated count', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const ReadinessBreakdownProjectedCard(
            readiness: sampleReadinessResult,
          ),
        ),
      );

      expect(find.text('PROJECTED EXAM SCORE'), findsOneWidget);
      expect(find.text('280 - 310'), findsOneWidget);
      expect(find.text('4/5 Calibrated'), findsOneWidget);
    });

    testWidgets('ReadinessBreakdownCourseCard renders course info and badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const ReadinessBreakdownCourseCard(
            sub: SubjectReadinessBreakdown(
              subjectName: 'Physics',
              courseCode: 'PHY 101',
              readinessPercent: 82,
              projectedGrade: 'A',
              coveragePercent: 0.85,
              accuracyPercent: 0.80,
              projectedScore: 82,
              maxScore: 100,
            ),
            examCategory: ExamCategory.waec,
            examTitle: 'WASSCE 2026',
            hasPastQuestions: true,
          ),
        ),
      );

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('PHY 101'), findsOneWidget);
      expect(find.text('82% · A'), findsOneWidget);
    });

    testWidgets('ReadinessBreakdownActionsSection renders suggestions and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const ReadinessBreakdownActionsSection(
            readiness: sampleReadinessResult,
            examTitle: 'WASSCE 2026',
          ),
        ),
      );

      expect(find.text('Primary Bottleneck Diagnostic'), findsOneWidget);
      expect(find.text('AI Sprint'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('CbtReadinessBreakdownSheet renders full diagnostic sheet content', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            height: 900,
            width: 450,
            child: CbtReadinessBreakdownSheet(
              readinessResult: sampleReadinessResult,
              examTitle: 'WASSCE Exam 2026',
              daysRemaining: 15,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CBT Readiness Breakdown'), findsOneWidget);
      expect(find.text('PROJECTED EXAM SCORE'), findsOneWidget);
      expect(find.text('REGISTERED COURSES BREAKDOWN'), findsOneWidget);
      expect(find.text('Chemistry'), findsOneWidget);
      expect(find.text('Primary Bottleneck Diagnostic'), findsOneWidget);
    });
  });
}
