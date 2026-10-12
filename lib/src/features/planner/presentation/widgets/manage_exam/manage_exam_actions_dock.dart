import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/cancel_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam/conclude_grade_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/postpone_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';

/// Bottom action buttons dock for updating, postponing, concluding, or deleting an assessment.
class ManageExamActionsDock extends StatelessWidget {
  const ManageExamActionsDock({
    required this.exam,
    required this.cubit,
    super.key,
  });

  final ExamEventEntity exam;
  final CramPlannerCubit cubit;

  void _confirmDelete(BuildContext context) {
    unawaited(
      AppDialog.show<bool>(
        context: context,
        title: 'Delete Assessment Countdown?',
        description:
            'Are you sure you want to remove the countdown for "${exam.examName}"? You can always add a new one anytime.',
        primaryActionText: 'Delete Countdown',
        isDestructive: true,
        onPrimaryAction: () async {
          AppFeedback.heavy();
          await cubit.deleteExamCountdown(exam.id);
        },
        secondaryActionText: 'Cancel',
      ).then((didDelete) {
        if (didDelete == true && context.mounted) {
          context.showSnackBar(
            message: 'Countdown for "${exam.examName}" deleted',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Status Action
        if (exam.isCancelled)
          FilledButton.icon(
            onPressed: () async {
              AppFeedback.heavy();
              await cubit.restoreAssessment(exam.id);
              if (context.mounted) {
                context.showSnackBar(
                  message:
                      '${exam.examName} restored to active study schedule',
                  type: SnackBarType.success,
                );
              }
            },
            icon: const Icon(Icons.restore_rounded, size: 17),
            label: const Text('Restore to Active Schedule'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusCard,
              ),
            ),
          )
        else if (exam.isCompleted)
          OutlinedButton.icon(
            onPressed: () async {
              AppFeedback.selection();
              await cubit.reopenAssessment(exam.id);
              if (context.mounted) {
                context.showSnackBar(
                  message: '${exam.examName} reopened for study planning',
                );
              }
            },
            icon: const Icon(Icons.replay_rounded, size: 16),
            label: Text(l10n.plannerReopenMilestone),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: colors.primary.withAlpha(120)),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusCard,
              ),
            ),
          )
        else
          FilledButton.icon(
            onPressed: () =>
                ConcludeGradeModalSheet.show(context, cubit: cubit, exam: exam),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
            label: Text(l10n.plannerConcludeMilestone),
            style: FilledButton.styleFrom(
              backgroundColor:
                  exam.isPast ? colors.warning : colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusCard,
              ),
            ),
          ),
        const SizedBox(height: 10),

        // Postpone & Cancel Actions Row (for uncompleted exams)
        if (!exam.isCompleted && !exam.isCancelled) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final nav = Navigator.of(context)..pop();
                    unawaited(
                      PostponeExamModalSheet.show(
                        nav.context,
                        exam: exam,
                        cubit: cubit,
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.update_rounded,
                    size: 16,
                    color: colors.warning,
                  ),
                  label: Text(
                    'Postpone',
                    style: TextStyle(color: colors.warning),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: colors.warning.withAlpha(120)),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusCard,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final nav = Navigator.of(context)..pop();
                    unawaited(
                      CancelExamModalSheet.show(
                        nav.context,
                        exam: exam,
                        cubit: cubit,
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: colors.error,
                  ),
                  label: Text(
                    'Cancel',
                    style: TextStyle(color: colors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: colors.error.withAlpha(120)),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusCard,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Action Buttons Row: Edit and Add
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context)..pop();
                  unawaited(
                    nav.context.router.push(
                      AddAcademicAssessmentRoute(
                        initialExam: exam,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(l10n.commonEdit),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: colors.surfaceBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusCard,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context)..pop();
                  unawaited(
                    nav.context.router.push(
                      AddAcademicAssessmentRoute(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l10n.commonAddNew),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusCard,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Delete Button
        TextButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: colors.error,
          ),
          label: Text(
            'Delete This Countdown',
            style: typography.caption.bold.copyWith(
              color: colors.error,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }
}
