import 'package:flutter/material.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Bottom action buttons for cancelling or saving/updating an academic assessment.
class AssessmentActionButtons extends StatelessWidget {
  const AssessmentActionButtons({
    required this.isEditing,
    required this.isEnabled,
    required this.onCancel,
    required this.onSubmit,
    super.key,
  });

  final bool isEditing;
  final bool isEnabled;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: AppButton(
            text: l10n.cancelAction,
            onPressed: onCancel,
            variant: AppButtonVariant.secondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: AppButton(
            text: isEditing
                ? l10n.updateExamCountdown
                : l10n.saveExamCountdown,
            isEnabled: isEnabled,
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }
}
