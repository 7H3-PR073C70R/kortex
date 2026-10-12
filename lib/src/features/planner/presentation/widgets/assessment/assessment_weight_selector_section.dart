import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Choice chips selector for optional course assessment grade weight percentage.
class AssessmentWeightSelectorSection extends StatelessWidget {
  const AssessmentWeightSelectorSection({
    required this.selectedWeightPercent,
    required this.onWeightSelected,
    super.key,
  });

  final double? selectedWeightPercent;
  final ValueChanged<double?> onWeightSelected;

  static const List<double?> availableWeights = [null, 0.10, 0.20, 0.30, 0.50];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Row(
      children: [
        Text(
          l10n.gradeWeightLabel,
          style: typography.caption.medium.copyWith(
            color: colors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableWeights.map((w) {
                final isSel = selectedWeightPercent == w;
                final label = w == null
                    ? l10n.optionalWeightHint
                    : '${(w * 100).toInt()}%';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    labelStyle: typography.caption.semiBold.copyWith(
                      color: isSel ? colors.white : colors.textSecondary,
                      fontSize: 11.5,
                    ),
                    selected: isSel,
                    selectedColor: colors.primary,
                    backgroundColor: colors.transparent,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      AppFeedback.selection();
                      onWeightSelected(w);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
