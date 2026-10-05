import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CbtPracticeConfigModalSheet extends HookWidget {
  const CbtPracticeConfigModalSheet({
    required this.title,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.allQuestions,
    required this.isMockExam,
    super.key,
  });

  final String title;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final List<PastQuestionEntity> allQuestions;
  final bool isMockExam;

  static List<PastQuestionEntity> generateCourseQuestions({
    required String courseId,
    required String courseCode,
    required String courseTitle,
  }) {
    final labels = ['A', 'B', 'C', 'D'];
    return List.generate(20, (i) {
      final qNum = i + 1;
      final correctIdx = (qNum - 1) % 4;
      return PastQuestionEntity(
        id: 'cbt_${courseCode.toLowerCase()}_$qNum',
        examType: ExamCategory.general,
        subject: courseTitle,
        year: 2024,
        questionNumber: qNum,
        prompt: 'Comprehensive Question #$qNum for $courseCode ($courseTitle): '
            'Which foundational concept or analytical method is primary when analyzing key topics in $courseTitle?',
        options: const [
          'Theoretical Framework & Analytical Principles (Method A)',
          'Empirical Validation & System Diagnostics (Method B)',
          'Standard Operational Protocol & Logic (Method C)',
          'Applied Synthesis & Conceptual Integration (Method D)',
        ],
        correctOptionIndex: correctIdx,
        correctOptionLabel: labels[correctIdx],
        explanation: 'Detailed Solution for Question #$qNum: Option ${labels[correctIdx]} directly addresses the fundamental domain requirements of $courseCode.',
        topic: 'Core Course Principles',
        courseId: courseId,
        courseCode: courseCode,
      );
    });
  }

  static Future<void> showForCourse(
    BuildContext context, {
    required CuratedCourseEntity course,
    bool isMockExam = false,
    List<PastQuestionEntity>? initialQuestions,
  }) {
    final questions = (initialQuestions != null && initialQuestions.isNotEmpty)
        ? initialQuestions
        : generateCourseQuestions(
            courseId: course.id,
            courseCode: course.courseCode,
            courseTitle: course.title,
          );

    return show(
      context,
      title: 'Practice ${course.courseCode} Past Questions',
      courseId: course.id,
      courseCode: course.courseCode,
      courseTitle: course.title,
      allQuestions: questions,
      isMockExam: isMockExam,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required List<PastQuestionEntity> allQuestions,
    required bool isMockExam,
  }) {
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 640,
      builder: (ctx) => CbtPracticeConfigModalSheet(
        title: title,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        allQuestions: allQuestions,
        isMockExam: isMockExam,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final questionsState = useState<List<PastQuestionEntity>>(allQuestions);
    final effectiveQuestions = questionsState.value;

    final userTrack = context.read<AuthBloc?>()?.state.userProfile?.targetTrack;
    final examCategory = (userTrack != null && userTrack.isNotEmpty)
        ? PastQuestionModel.parseExamCategory(userTrack)
        : null;

    useEffect(() {
      if (locator.isRegistered<PastQuestionsRepository>()) {
        try {
          unawaited(
            locator<PastQuestionsRepository>()
                .getPastQuestions(
                  examCategory: examCategory,
                  courseId: courseId,
                  courseCode: courseCode,
                  subject: courseTitle,
                )
                .then((res) {
              res.fold(
                (_) {},
                (fetched) {
                  if (fetched.isNotEmpty) {
                    questionsState.value = fetched;
                  }
                },
              );
            }),
          );
        } on Object catch (_) {}
      }
      return null;
    }, [courseId, courseCode, examCategory]);

    // Extract unique available years sorted descending
    final availableYears = useMemoized(() {
      final years = <int>{};
      for (final q in effectiveQuestions) {
        if (q.year > 1990) {
          years.add(q.year);
        }
      }
      final list = years.toList()..sort((a, b) => b.compareTo(a));
      return list;
    }, [effectiveQuestions]);

    // Selected Year: null means "Random (All Years)"
    final selectedYear = useState<int?>(null);
    final isMillionaire = useState<bool>(false);

    // The page opens in the mode its trigger implied, but the student can
    // still switch between practice and exam here before starting.
    final isExam = useState<bool>(isMockExam);

    // Recommended default counts
    final recommendedCount = isMockExam ? 40 : 20;
    final availableCountForSelection = useMemoized(() {
      if (selectedYear.value == null) {
        return effectiveQuestions.length;
      }
      return effectiveQuestions.where((q) => q.year == selectedYear.value).length;
    }, [selectedYear.value, effectiveQuestions]);

    // Question count state: default to min(recommendedCount, availableCount)
    final selectedCount = useState<int>(
      effectiveQuestions.length >= recommendedCount
          ? recommendedCount
          : effectiveQuestions.length.clamp(1, 100),
    );

    final isStarting = useState<bool>(false);
    final reduceMotion = quizReduceMotion(context);

    // Available count options
    final countOptions = [
      10,
      20,
      30,
      40,
    ].where((c) => c <= effectiveQuestions.length || c == 10).toList();
    if (!countOptions.contains(effectiveQuestions.length) &&
        effectiveQuestions.length < 40 &&
        effectiveQuestions.isNotEmpty) {
      countOptions
        ..add(effectiveQuestions.length)
        ..sort();
    }

    void handleStart() {
      if (effectiveQuestions.isEmpty) return;
      isStarting.value = true;
      AppFeedback.medium();

      // Filter questions by year if selected
      var candidateQuestions = selectedYear.value == null
          ? List<PastQuestionEntity>.from(effectiveQuestions)
          : effectiveQuestions.where((q) => q.year == selectedYear.value).toList();

      if (candidateQuestions.isEmpty) {
        candidateQuestions = List<PastQuestionEntity>.from(effectiveQuestions);
      }

      // Shuffle for randomness
      candidateQuestions.shuffle();

      // Take desired question count (12 for Millionaire mode)
      final countToTake = isMillionaire.value ? 12 : selectedCount.value;
      final finalQuestions = candidateQuestions.take(countToTake).toList();

      final quizQuestions = finalQuestions
          .map(QuizQuestionEntity.fromPastQuestion)
          .toList();

      final durationMinutes = isMillionaire.value
          ? null
          : (isExam.value ? quizQuestions.length : null);

      final router = context.router;
      Navigator.of(context).pop();

      unawaited(
        router.push(
          QuizWorkspaceRoute(
            deckId: 'cbt_${courseId}_${DateTime.now().millisecondsSinceEpoch}',
            deckTitle: isMillionaire.value
                ? '$courseCode Millionaire Challenge'
                : '$courseCode $title',
            subject: courseTitle,
            durationMinutes: durationMinutes,
            initialQuestions: quizQuestions,
            courseId: courseId,
            courseCode: courseCode,
            assessmentMode: isMillionaire.value
                ? AssessmentMode.millionaireMode
                : (isExam.value
                      ? AssessmentMode.examSimulationMode
                      : AssessmentMode.discoveryMode),
          ),
        ),
      );
    }

    final currentMode = isMillionaire.value
        ? QuizPracticeMode.millionaire
        : (isExam.value ? QuizPracticeMode.exam : QuizPracticeMode.practice);

    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Align(
      alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder,
            ),
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 100 : 35),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            top: isDesktop,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDesktop) ...[
                    // 1. Accessible Drag Handle (mobile only)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.surfaceBorderHighlight,
                          borderRadius: BorderRadius.circular(AppRadius.micro),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 2. Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: typography.title2.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$courseCode • $courseTitle',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textMuted,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. Mode Selection (Segmented Control + Dynamic Caption)
                  const QuizSectionLabel(label: 'Quiz Mode'),
                  QuizModeSegmentedControl(
                    currentMode: currentMode,
                    reduceMotion: reduceMotion,
                    onModeSelected: (mode) {
                      switch (mode) {
                        case QuizPracticeMode.practice:
                          isExam.value = false;
                          isMillionaire.value = false;
                        case QuizPracticeMode.exam:
                          isExam.value = true;
                          isMillionaire.value = false;
                        case QuizPracticeMode.millionaire:
                          isExam.value = false;
                          isMillionaire.value = true;
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  QuizModeDescription(
                    mode: currentMode,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 18),

                  // 4. Question Source / Exam Year (Single-Row Horizontal Pills)
                  QuizSectionLabel(
                    label: 'Exam Year',
                    trailing: Text(
                      selectedYear.value == null
                          ? 'All years shuffled'
                          : 'Paper year ${selectedYear.value}',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        QuizYearPill(
                          label: 'All Years',
                          icon: Icons.shuffle_rounded,
                          isSelected: selectedYear.value == null,
                          reduceMotion: reduceMotion,
                          onTap: () {
                            AppFeedback.light();
                            selectedYear.value = null;
                          },
                        ),
                        ...availableYears.map((year) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: QuizYearPill(
                              label: '$year',
                              isSelected: selectedYear.value == year,
                              reduceMotion: reduceMotion,
                              onTap: () {
                                AppFeedback.light();
                                selectedYear.value = year;
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5. Question Count (Evenly Expanded Pills - Zero Overflow)
                  QuizSectionLabel(
                    label: 'Question Count',
                    trailing: Text(
                      isMillionaire.value
                          ? '12 Tiers Fixed'
                          : (isExam.value
                                ? '${selectedCount.value}m limit'
                                : '$availableCountForSelection available'),
                      style: typography.caption.bold.copyWith(
                        color: isMillionaire.value
                            ? colors.warning
                            : colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (isMillionaire.value)
                    const QuizMillionaireNotice()
                  else
                    Row(
                      children: countOptions.map((count) {
                        final isSelected = selectedCount.value == count;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            child: QuizCountOptionPill(
                              count: count,
                              isSelected: isSelected,
                              reduceMotion: reduceMotion,
                              onTap: () {
                                AppFeedback.light();
                                selectedCount.value = count;
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),

                  // 6. Launch CTA Button
                  ShrinkableButton(
                    onTap: isStarting.value ? null : handleStart,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isMillionaire.value
                            ? colors.warning
                            : colors.primary,
                        borderRadius: BorderRadius.circular(
                          AppRadius.panel,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isMillionaire.value
                                        ? colors.warning
                                        : colors.primary)
                                    .withAlpha(isDark ? 60 : 30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isStarting.value)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else ...[
                            Icon(
                              isMillionaire.value
                                  ? Icons.workspace_premium_rounded
                                  : (isExam.value
                                        ? Icons.timer_outlined
                                        : Icons.play_arrow_rounded),
                              color: colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isMillionaire.value
                                  ? 'Start 12-Tier Millionaire'
                                  : (isExam.value
                                        ? 'Start ${selectedCount.value} Questions • ${selectedCount.value}m'
                                        : 'Start ${selectedCount.value} Questions'),
                              style: typography.callout.bold.copyWith(
                                color: colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
