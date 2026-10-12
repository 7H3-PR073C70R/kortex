import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_course_chips.dart';

/// Tab view for starting a public 1v1 quick match.
class QuizDuelQuickMatchTab extends StatelessWidget {
  const QuizDuelQuickMatchTab({
    required this.subjects,
    required this.selectedSubject,
    required this.selectedQuestionCount,
    required this.hasCustomCourses,
    required this.onSelectSubject,
    required this.onSelectQuestionCount,
    this.dashboardBloc,
    super.key,
  });

  final List<String> subjects;
  final String selectedSubject;
  final int selectedQuestionCount;
  final bool hasCustomCourses;
  final void Function(String) onSelectSubject;
  final void Function(int) onSelectQuestionCount;
  final DashboardBloc? dashboardBloc;

  static const List<int> questionCounts = [5, 10, 15];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasCustomCourses)
          DefaultSubjectsBanner(dashboardBloc: dashboardBloc),
        Text(
          'Subject',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...subjects.map((sub) {
              final isSelected = selectedSubject == sub;
              return ChoiceChip(
                label: Text(sub),
                selected: isSelected,
                selectedColor: colors.primary.withValues(alpha: 0.2),
                backgroundColor: colors.surfaceSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.4)
                        : colors.surfaceBorder.withValues(alpha: 0.3),
                  ),
                ),
                labelStyle: context.typography.body.regular.copyWith(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                onSelected: (val) {
                  if (val) {
                    AppFeedback.selection();
                    onSelectSubject(sub);
                  }
                },
              );
            }),
            AddCourseChip(dashboardBloc: dashboardBloc),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Questions',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: questionCounts.map((count) {
            final isSelected = selectedQuestionCount == count;
            return ChoiceChip(
              label: Text('$count questions${count == 10 ? ' (standard)' : ''}'),
              selected: isSelected,
              selectedColor: colors.primary.withValues(alpha: 0.2),
              backgroundColor: colors.surfaceSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.badge),
                side: BorderSide(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.4)
                      : colors.surfaceBorder.withValues(alpha: 0.3),
                ),
              ),
              labelStyle: context.typography.body.regular.copyWith(
                color: isSelected ? colors.primary : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              onSelected: (val) {
                if (val) {
                  AppFeedback.selection();
                  onSelectQuestionCount(count);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Match Rule Highlight
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 20,
                color: colors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$selectedQuestionCount questions • 15s adaptive timer • Faster answers earn up to +50 speed bonus.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
