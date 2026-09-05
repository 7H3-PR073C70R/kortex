import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';

class ManageExamModalSheet extends StatelessWidget {
  const ManageExamModalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CramPlannerCubit>(),
        child: const ManageExamModalSheet(),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CramPlannerCubit cubit,
    ExamEventEntity exam,
  ) {
    unawaited(
      AppDialog.show<void>(
        context: context,
        title: 'Delete Exam Countdown?',
        description:
            'Are you sure you want to remove the countdown for "${exam.examName}"? You can always add a new one anytime.',
        primaryActionText: 'Delete Countdown',
        isDestructive: true,
        onPrimaryAction: () async {
          AppFeedback.heavy();
          await cubit.deleteExamCountdown(exam.id);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        secondaryActionText: 'Cancel',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, state) {
        final exam = state.selectedExam;
        final allExams = state.activeExams;
        final cubit = context.read<CramPlannerCubit>();

        if (exam == null) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No Active Countdown',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: l10n.addExamTitle,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(AddExamModalSheet.show(context));
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final days = exam.daysRemaining;
        final pace = state.dynamicDailyTarget;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Exam Countdown',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Active Exam Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary.withAlpha(180)
                        : colors.surfaceSecondary.withAlpha(120),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 90 : 50),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${exam.subjectTrack} Track',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            '${exam.targetDate.year}-${exam.targetDate.month.toString().padLeft(2, '0')}-${exam.targetDate.day.toString().padLeft(2, '0')}',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        exam.examName,
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 15,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.daysUntilExam(days, exam.examName),
                            style: typography.footnote.semiBold.copyWith(
                              color: colors.warning,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.recommendedDailyPace(pace),
                            style: typography.footnote.semiBold.copyWith(
                              color: colors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // If multiple exams exist, show switch list
                if (allExams.length > 1) ...[
                  Text(
                    'All Saved Countdowns (${allExams.length})',
                    style: typography.subhead.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...allExams.map((e) {
                    final isSelected = e.id == exam.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          cubit.selectExam(e.id);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? colors.primary.withAlpha(isDark ? 40 : 20)
                                : (isDark
                                      ? colors.surfacePrimary.withAlpha(100)
                                      : colors.surfaceSecondary.withAlpha(80)),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : colors.surfaceBorder.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: isSelected
                                    ? colors.primary
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.examName,
                                  style: typography.body.semiBold.copyWith(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.daysRemaining}d left',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // Action Buttons Row: Edit and Add
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(
                            AddExamModalSheet.show(
                              context,
                              initialExam: exam,
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_calendar_rounded, size: 17),
                        label: const Text('Edit Countdown'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          foregroundColor: colors.primary,
                          side: BorderSide(color: colors.primary.withAlpha(120)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(AddExamModalSheet.show(context));
                        },
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('Add Another'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Destructive Delete Button
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, cubit, exam),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colors.error,
                  ),
                  label: Text(
                    'Delete This Countdown',
                    style: typography.callout.bold.copyWith(
                      color: colors.error,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
