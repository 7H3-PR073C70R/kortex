import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class CancelExamModalSheet extends StatefulWidget {
  const CancelExamModalSheet({
    required this.exam,
    super.key,
  });

  final ExamEventEntity exam;

  static Future<void> show(
    BuildContext context, {
    required ExamEventEntity exam,
    CramPlannerCubit? cubit,
  }) {
    final cramPlannerCubit = cubit ?? context.read<CramPlannerCubit>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: cramPlannerCubit,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: CancelExamModalSheet(exam: exam),
          ),
        ),
      ),
    );
  }

  @override
  State<CancelExamModalSheet> createState() => _CancelExamModalSheetState();
}

class _CancelExamModalSheetState extends State<CancelExamModalSheet> {
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.exam.cancellationReason != null) {
      _reasonController.text = widget.exam.cancellationReason!;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submitCancel() {
    final cubit = context.read<CramPlannerCubit>();
    final reasonText = _reasonController.text.trim();

    AppFeedback.heavy();
    unawaited(
      cubit.cancelAssessment(
        examId: widget.exam.id,
        reason: reasonText.isNotEmpty ? reasonText : null,
      ),
    );

    Navigator.of(context).pop();
    context.showSnackBar(
      message: '"${widget.exam.examName}" marked as cancelled',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
          border: Border.all(
            color: colors.error.withAlpha(isDark ? 60 : 30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colors.textSecondary.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cancel_outlined,
                        color: colors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cancel Assessment',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Are you sure you want to cancel "${widget.exam.examName}"? Its workload will be excluded from active study goals. You can restore it anytime.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Cancellation Reason Input Field
            AppTextField(
              controller: _reasonController,
              label: 'Cancellation Reason (Optional)',
              hintText: 'e.g. Test cancelled by professor, course dropped',
              prefixIcon: Icon(
                Icons.info_outline_rounded,
                color: colors.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: colors.surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    child: Text(
                      'Keep Active',
                      style: typography.callout.bold.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _submitCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 17),
                    label: const Text('Cancel Assessment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
