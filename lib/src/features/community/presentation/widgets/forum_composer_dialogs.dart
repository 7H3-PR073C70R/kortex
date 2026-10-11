import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Modal sheets providing quick math templates and Greek/math symbols for forum composers.
class ForumComposerDialogs {
  const ForumComposerDialogs._();

  /// Displays a modal sheet of common LaTeX formula templates (fractions, integrals, matrices, etc.).
  static void showLatexSnippetDialog(
    BuildContext context,
    void Function(String snippet) onInsert,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final snippets = [
      {'label': 'Fraction', 'snippet': r'$\frac{a}{b}$'},
      {'label': 'Square Root', 'snippet': r'$\sqrt{x}$'},
      {'label': 'Exponent', 'snippet': r'$x^{2}$'},
      {'label': 'Integral', 'snippet': r'$\int_{a}^{b} f(x) dx$'},
      {'label': 'Summation', 'snippet': r'$\sum_{i=1}^{n} x_i$'},
      {'label': 'Limit', 'snippet': r'$\lim_{x \to \infty}$'},
      {
        'label': 'Matrix 2x2',
        'snippet': r'$$\begin{pmatrix} a & b \\ c & d \end{pmatrix}$$',
      },
    ];

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 480,
        builder: (ctx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
          return SafeArea(
            child: Container(
              decoration: isDesktop
                  ? BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    )
                  : null,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert LaTeX Formula',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...snippets.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        s['label']!,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        s['snippet']!,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: SizedBox(
                        width: 90,
                        height: 28,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: LatexRichViewer(
                            text: s['snippet']!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      onTap: () {
                        onInsert(s['snippet']!);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Displays a modal grid of mathematical and Greek symbols for quick insertion.
  static void showMathSymbolDialog(
    BuildContext context,
    void Function(String snippet) onInsert,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    const symbols = [
      'π', 'θ', 'α', 'β', 'γ', 'λ', 'μ', 'σ', 'ω', 'Δ',
      '≈', '≠', '≤', '≥', '±', '×', '÷', '√', '∞', '∫',
      '∑', '∂', '∇', '∈', '∉', '⊂', '⊆', '∪', '∩', '→',
    ];

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 440,
        builder: (ctx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
          return SafeArea(
            child: Container(
              decoration: isDesktop
                  ? BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    )
                  : null,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert Math / Greek Symbol',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: symbols.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemBuilder: (gridCtx, idx) {
                      final sym = symbols[idx];
                      return InkWell(
                        onTap: () {
                          onInsert(sym);
                          Navigator.of(ctx).pop();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary
                                : colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.primary.withAlpha(40),
                            ),
                          ),
                          child: Text(
                            sym,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
