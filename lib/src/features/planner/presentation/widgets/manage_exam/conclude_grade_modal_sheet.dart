import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Modal sheet for concluding an assessment and recording the student's achieved score.
abstract final class ConcludeGradeModalSheet {
  static void show(
    BuildContext context, {
    required CramPlannerCubit cubit,
    required ExamEventEntity exam,
  }) {
    var score = 85.0;
    var rollover = true;

    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 520,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (dialogCtx, setModalState) {
              final colors = ctx.colors;
              final typography = ctx.typography;
              final isDark = ctx.isDarkMode;
              final l10n = ctx.l10n;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: isDesktop
                        ? BorderRadius.circular(AppRadius.dialog)
                        : const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.dialog),
                          ),
                    border: isDesktop
                        ? Border.all(
                            color: colors.surfaceBorder
                                .withAlpha(isDark ? 90 : 50),
                          )
                        : null,
                    boxShadow: isDesktop
                        ? [
                            BoxShadow(
                              color: colors.black
                                  .withAlpha(isDark ? 100 : 35),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Conclude & Record Grade',
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Record your achieved score for "${exam.examName}". Any difficult or missed flashcards can be rolled over to your continuous review queue.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Achieved Score',
                            style: typography.body.semiBold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary
                                  .withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.primary.withAlpha(100),
                              ),
                            ),
                            child: Text(
                              '${score.toInt()}%',
                              style: typography.callout.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: score,
                        max: 100,
                        divisions: 100,
                        activeColor: colors.primary,
                        onChanged: (val) {
                          setModalState(() {
                            score = val;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: rollover,
                        activeColor: colors.primary,
                        title: Text(
                          'Rollover unmastered cards to Final Exam review',
                          style: typography.caption.medium.copyWith(
                            color: colors.textPrimary,
                            fontSize: 12.5,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            rollover = val ?? true;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          AppFeedback.celebration();
                          await cubit.completeAssessment(
                            examId: exam.id,
                            scorePercent: score / 100.0,
                            rolloverWeakCards: rollover,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ctx.showSnackBar(
                              message:
                                  'Assessment recorded with ${score.toInt()}% score!',
                              type: SnackBarType.success,
                            );
                          }
                        },
                        child: Text(l10n.plannerSaveArchiveMilestone),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
