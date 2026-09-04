import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

class McqOptionCard extends StatelessWidget {
  const McqOptionCard({
    required this.optionText,
    required this.index,
    required this.isSelected,
    required this.isAnswered,
    required this.isCorrect,
    required this.onTap,
    super.key,
  });

  final String optionText;
  final int index;
  final bool isSelected;
  final bool isAnswered;
  final bool isCorrect;
  final VoidCallback onTap;

  String get _letterPrefix => String.fromCharCode(65 + index); // A, B, C, D

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;

    var borderColor = colors.surfaceBorder;
    var bgColor = theme.colorScheme.surface.withValues(alpha: 0.6);
    Widget? trailingIcon;

    if (isAnswered) {
      if (isCorrect) {
        borderColor = colors.success;
        bgColor = colors.success.withValues(alpha: 0.15);
        trailingIcon = Icon(
          Icons.check_circle_rounded,
          color: colors.success,
          size: 20,
        );
      } else if (isSelected) {
        borderColor = colors.error;
        bgColor = colors.error.withValues(alpha: 0.15);
        trailingIcon = Icon(
          Icons.cancel_rounded,
          color: colors.error,
          size: 20,
        );
      }
    } else if (isSelected) {
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    }

    return Semantics(
      button: true,
      enabled: !isAnswered,
      label: 'Option $_letterPrefix: $optionText',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: isAnswered ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isSelected || (isAnswered && isCorrect) ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Prefix Badge
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected || (isAnswered && isCorrect)
                        ? borderColor.withValues(alpha: 0.2)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _letterPrefix,
                    style: context.typography.footnote.bold.copyWith(
                      color: isSelected || (isAnswered && isCorrect)
                          ? borderColor
                          : colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    optionText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  trailingIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
