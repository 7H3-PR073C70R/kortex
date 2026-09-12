import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Categories of quality issues reported for past questions.
enum FlagQuestionReason {
  typo('Typographical error in question text'),
  wrongAnswer('Incorrect answer key or options'),
  badExplanation('Misleading or poor explanation'),
  latexError('Broken LaTeX formula rendering'),
  offSyllabus('Outdated or off-syllabus topic')
  ;

  const FlagQuestionReason(this.label);
  final String label;
}

/// Community quality audit modal for flagging flawed quiz questions (QZ-14).
class FlagQuestionBottomSheet extends HookWidget {
  const FlagQuestionBottomSheet({
    required this.questionId, required this.questionSnippet, super.key,
    this.onSubmitReport,
  });

  final String questionId;
  final String questionSnippet;
  final void Function(String questionId, FlagQuestionReason reason, String notes)? onSubmitReport;

  static Future<void> show(
    BuildContext context, {
    required String questionId,
    required String questionSnippet,
    void Function(String questionId, FlagQuestionReason reason, String notes)? onSubmitReport,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => FlagQuestionBottomSheet(
        questionId: questionId,
        questionSnippet: questionSnippet,
        onSubmitReport: onSubmitReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedReason = useState<FlagQuestionReason>(FlagQuestionReason.wrongAnswer);
    final commentController = useTextEditingController();
    final isSubmitting = useState<bool>(false);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.flag_rounded, color: colors.error, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Report Question Issue',
                  style: typography.title2.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Question Snippet Quote
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"$questionSnippet"',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Select Issue Category:',
              style: typography.caption.regular.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // Reasons List
            ...FlagQuestionReason.values.map((reason) {
              final isSelected = selectedReason.value == reason;
              return InkWell(
                onTap: () {
                  AppFeedback.selection();
                  selectedReason.value = reason;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.surfaceBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18,
                        color: isSelected ? colors.primary : colors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason.label,
                          style: typography.caption.regular.copyWith(
                            color: isSelected ? colors.textPrimary : colors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            // Comment input
            TextField(
              controller: commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Additional details or proposed correction...',
                hintStyle: typography.caption.regular.copyWith(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surfacePrimary,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.surfaceBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Submit Button
            AppButton(
              text: isSubmitting.value ? 'Submitting Report...' : 'Submit Quality Report',
              isLoading: isSubmitting.value,
              onPressed: () {
                AppFeedback.correct();
                isSubmitting.value = true;
                onSubmitReport?.call(
                  questionId,
                  selectedReason.value,
                  commentController.text.trim(),
                );
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
