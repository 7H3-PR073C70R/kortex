import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Horizontal filter bar for filtering assessments by type or completion.
class ExamTimetableFilterBar extends StatelessWidget {
  const ExamTimetableFilterBar({
    required this.allExams,
    required this.selectedFilterType,
    required this.showCompletedOnly,
    required this.onFilterChanged,
    super.key,
  });

  final List<ExamEventEntity> allExams;
  final AssessmentType? selectedFilterType;
  final bool showCompletedOnly;
  final void Function({
    required AssessmentType? selectedFilterType,
    required bool showCompletedOnly,
  }) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final uncompleted = allExams.where((e) => !e.isCompleted).toList();
    final allCount = uncompleted.length;
    final quizzesCount = uncompleted
        .where((e) => e.assessmentType == AssessmentType.quiz)
        .length;
    final testsCount = uncompleted
        .where((e) => e.assessmentType == AssessmentType.classTest)
        .length;
    final midtermsCount = uncompleted
        .where((e) => e.assessmentType == AssessmentType.midterm)
        .length;
    final finalsCount = uncompleted
        .where((e) =>
            e.assessmentType == AssessmentType.finalExam ||
            e.assessmentType == AssessmentType.mockExam)
        .length;
    final completedCount = allExams.where((e) => e.isCompleted).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: '${l10n.filterAll} ($allCount)',
            isSelected: selectedFilterType == null && !showCompletedOnly,
            onSelected: () {
              AppFeedback.selection();
              onFilterChanged(
                selectedFilterType: null,
                showCompletedOnly: false,
              );
            },
            colors: colors,
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context,
            label: '${l10n.filterQuizzes} ($quizzesCount)',
            isSelected: !showCompletedOnly && selectedFilterType == AssessmentType.quiz,
            onSelected: () {
              AppFeedback.selection();
              onFilterChanged(
                selectedFilterType: AssessmentType.quiz,
                showCompletedOnly: false,
              );
            },
            colors: colors,
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context,
            label: '${l10n.filterTests} ($testsCount)',
            isSelected: !showCompletedOnly && selectedFilterType == AssessmentType.classTest,
            onSelected: () {
              AppFeedback.selection();
              onFilterChanged(
                selectedFilterType: AssessmentType.classTest,
                showCompletedOnly: false,
              );
            },
            colors: colors,
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context,
            label: '${l10n.filterMidterms} ($midtermsCount)',
            isSelected: !showCompletedOnly && selectedFilterType == AssessmentType.midterm,
            onSelected: () {
              AppFeedback.selection();
              onFilterChanged(
                selectedFilterType: AssessmentType.midterm,
                showCompletedOnly: false,
              );
            },
            colors: colors,
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context,
            label: '${l10n.filterFinals} ($finalsCount)',
            isSelected: !showCompletedOnly && selectedFilterType == AssessmentType.finalExam,
            onSelected: () {
              AppFeedback.selection();
              onFilterChanged(
                selectedFilterType: AssessmentType.finalExam,
                showCompletedOnly: false,
              );
            },
            colors: colors,
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context,
            label: '${l10n.filterCompleted} ($completedCount)',
            isSelected: showCompletedOnly,
            onSelected: () {
              AppFeedback.selection();
              onFilterChanged(
                selectedFilterType: null,
                showCompletedOnly: true,
              );
            },
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required AppThemeColorsExtension colors,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary,
      labelStyle: context.typography.caption.bold.copyWith(
        color: isSelected ? colors.white : colors.textSecondary,
        fontSize: 11.5,
      ),
      backgroundColor: colors.surfaceSecondary.withAlpha(80),
      visualDensity: VisualDensity.compact,
    );
  }
}
