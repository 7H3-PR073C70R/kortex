import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Live rendering box for mathematical formulas formatted in LaTeX with error fallback.
class LatexMathPreviewBox extends StatelessWidget {
  const LatexMathPreviewBox({
    required this.latexFormula,
    required this.onRetryCleaned,
    super.key,
  });

  final String latexFormula;
  final ValueChanged<String> onRetryCleaned;

  @override
  Widget build(BuildContext context) {
    if (latexFormula.trim().isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.liveFormulaPreviewLabel,
          style: typography.caption.medium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? colors.black.withAlpha(80)
                : colors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 60 : 30),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              latexFormula
                  .replaceAll(r'$$', '')
                  .replaceAll(r'$', '')
                  .trim(),
              textStyle: typography.body.bold.copyWith(
                color: isDark ? colors.syllabotAccent : colors.primary,
                fontSize: 16,
              ),
              onErrorFallback: (err) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Formula parser error: ${err.message}',
                    style: typography.caption.medium.copyWith(
                      color: colors.warning,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final cleaned = latexFormula
                          .replaceAll(r'$$', '')
                          .replaceAll(r'$', '')
                          .replaceAll(r'\(', '')
                          .replaceAll(r'\)', '')
                          .replaceAll(r'\[', '')
                          .replaceAll(r'\]', '')
                          .trim();
                      onRetryCleaned(cleaned);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warning.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colors.warning.withAlpha(80),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Retry Cleaned',
                        style: typography.caption.bold.copyWith(
                          color: colors.warning,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
