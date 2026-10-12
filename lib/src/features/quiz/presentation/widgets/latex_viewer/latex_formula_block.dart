import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/utils/latex_ast_cache.dart';

/// A dedicated block LaTeX display widget for standalone equations (e.g. formula box).
class LatexFormulaBlock extends StatelessWidget {
  const LatexFormulaBlock({
    required this.formula,
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final String formula;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final clean = LatexAstCache.instance.getOrCleanFormula(formula);
    final fallbackReadable =
        LatexAstCache.instance.formatLatexHumanReadableFallback(formula);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg =
        backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerLowest);
    final border =
        borderColor ?? theme.colorScheme.primary.withValues(alpha: 0.25);
    final style =
        textStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Math.tex(
          clean,
          textStyle: style,
          onErrorFallback: (err) => Text(
            fallbackReadable.isNotEmpty ? fallbackReadable : clean,
            style: style?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
}
