import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
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

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required List<PastQuestionEntity> allQuestions,
    required bool isMockExam,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

    // Extract unique available years sorted descending
    final availableYears = useMemoized(() {
      final years = <int>{};
      for (final q in allQuestions) {
        if (q.year > 1990) {
          years.add(q.year);
        }
      }
      final list = years.toList()..sort((a, b) => b.compareTo(a));
      return list;
    }, [allQuestions]);

    // Selected Year: null means "Random (All Years)"
    final selectedYear = useState<int?>(null);

    // Recommended default counts
    final recommendedCount = isMockExam ? 40 : 20;
    final availableCountForSelection = useMemoized(() {
      if (selectedYear.value == null) {
        return allQuestions.length;
      }
      return allQuestions.where((q) => q.year == selectedYear.value).length;
    }, [selectedYear.value, allQuestions]);

    // Question count state: default to min(recommendedCount, availableCount)
    final selectedCount = useState<int>(
      allQuestions.length >= recommendedCount ? recommendedCount : allQuestions.length.clamp(1, 100),
    );

    final isStarting = useState<bool>(false);

    // Available count options
    final countOptions = [10, 20, 30, 40].where((c) => c <= allQuestions.length || c == 10).toList();
    if (!countOptions.contains(allQuestions.length) && allQuestions.length < 40 && allQuestions.isNotEmpty) {
      countOptions
        ..add(allQuestions.length)
        ..sort();
    }

    void handleStart() {
      if (allQuestions.isEmpty) return;
      isStarting.value = true;
      AppFeedback.medium();

      // Filter questions by year if selected
      var candidateQuestions = selectedYear.value == null
          ? List<PastQuestionEntity>.from(allQuestions)
          : allQuestions.where((q) => q.year == selectedYear.value).toList();

      if (candidateQuestions.isEmpty) {
        candidateQuestions = List<PastQuestionEntity>.from(allQuestions);
      }

      // Shuffle for randomness
      candidateQuestions.shuffle();

      // Take desired question count
      final finalQuestions = candidateQuestions.take(selectedCount.value).toList();

      final quizQuestions = finalQuestions.map(QuizQuestionEntity.fromPastQuestion).toList();

      final durationMinutes = isMockExam ? (quizQuestions.length * 1.5).round() : null;

      Navigator.of(context).pop();

      unawaited(
        context.router.push(
          QuizWorkspaceRoute(
            deckId: 'cbt_${courseId}_${DateTime.now().millisecondsSinceEpoch}',
            deckTitle: '$courseCode $title',
            subject: courseTitle,
            durationMinutes: durationMinutes,
            initialQuestions: quizQuestions,
            courseId: courseId,
            courseCode: courseCode,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? colors.surfaceBorderHighlight.withAlpha(70) : colors.surfaceBorder,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: typography.title2.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$courseCode • $courseTitle',
                          style: typography.caption.regular.copyWith(
                            color: colors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Practice Mode Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isMockExam
                      ? colors.primary.withAlpha(isDark ? 30 : 15)
                      : colors.syllabotAccent.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMockExam
                        ? colors.primary.withAlpha(isDark ? 70 : 40)
                        : colors.syllabotAccent.withAlpha(isDark ? 70 : 40),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMockExam ? Icons.timer_outlined : Icons.bolt_rounded,
                      color: isMockExam ? colors.primary : colors.syllabotAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMockExam ? 'Timed Examination Mode' : 'Interactive Drill Mode',
                            style: typography.caption.bold.copyWith(
                              color: isMockExam ? colors.primary : colors.syllabotAccent,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMockExam
                                ? 'Simulates official CBT conditions (~1.5m per question) with score analysis.'
                                : 'Untimed drill with instant answer checks and step-by-step solutions.',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Choose Year
              Text(
                'Select Year',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _ChoiceChip(
                      label: 'Random (All Years)',
                      isSelected: selectedYear.value == null,
                      badge: 'Recommended',
                      onTap: () {
                        AppFeedback.light();
                        selectedYear.value = null;
                      },
                    ),
                    ...availableYears.map((year) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _ChoiceChip(
                          label: '$year',
                          isSelected: selectedYear.value == year,
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
              const SizedBox(height: 20),

              // 2. Choose Question Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Number of Questions',
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$availableCountForSelection available',
                    style: typography.caption.regular.copyWith(
                      color: colors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: countOptions.map((count) {
                  final isRecommended = count == recommendedCount;
                  return _ChoiceChip(
                    label: '$count Questions',
                    isSelected: selectedCount.value == count,
                    badge: isRecommended ? 'Recommended' : null,
                    onTap: () {
                      AppFeedback.light();
                      selectedCount.value = count;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Start Action Button
              AppButton(
                text: isMockExam
                    ? 'Start Mock Exam (${selectedCount.value} Questions)'
                    : 'Start Practice Drill (${selectedCount.value} Questions)',
                isLoading: isStarting.value,
                onPressed: isStarting.value ? null : handleStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : (isDark ? colors.surfaceSecondary.withAlpha(150) : colors.surfacePrimary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : (isDark ? colors.surfaceBorderHighlight.withAlpha(70) : colors.surfaceBorder),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.white : colors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.white.withAlpha(40)
                      : colors.primary.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.primary,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
