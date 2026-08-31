import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

class LatexCardContentViewer extends StatelessWidget {
  const LatexCardContentViewer({
    required this.text,
    this.latexFormula,
    this.isBackFace = false,
    super.key,
  });

  final String text;
  final String? latexFormula;
  final bool isBackFace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final baseStyle =
        isBackFace ? typography.callout.medium : typography.title3.bold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary text
        Text(
          text,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: colors.textPrimary,
            fontSize: isBackFace ? 16 : 18.5,
            height: 1.35,
          ),
        ),

        // Optional LaTeX Formula Box
        if (latexFormula != null && latexFormula!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary.withAlpha(160)
                  : colors.surfaceSecondary.withAlpha(190),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 90 : 60),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 30 : 10),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Math.tex(
                latexFormula!,
                textStyle: TextStyle(
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
                onErrorFallback: (err) => Text(
                  latexFormula!,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
