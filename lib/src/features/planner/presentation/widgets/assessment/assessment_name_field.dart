import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Text field for editing the academic assessment name.
class AssessmentNameField extends StatelessWidget {
  const AssessmentNameField({
    required this.controller,
    required this.selectedType,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final AssessmentType selectedType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return AppTextField(
      controller: controller,
      label: l10n.examNameLabel,
      hintText: l10n.examModalExamTitleHint,
      prefixIcon: Icon(
        selectedType.icon,
        color: colors.textSecondary,
        size: 18,
      ),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.examNameRequired;
        }
        if (value.trim().length > 100) {
          return 'Assessment name cannot exceed 100 characters';
        }
        return null;
      },
    );
  }
}
