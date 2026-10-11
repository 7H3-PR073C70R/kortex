import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal sheets for inserting LaTeX formulas and Greek/math symbols.
abstract final class CreateDiscussionFormulaSheets {
  static void showMathFormulaSheet(
    BuildContext context, {
    required ValueChanged<String> onInsert,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final formulas = [
      r'$$\mathcal{L}_{\text{cost}} = \sum_{i=1}^{k} \min_{j} \| x_i - \mu_j \|_2^2$$',
      r'$$f(x) = \int_{-\infty}^{\infty} e^{-x^2} dx$$',
      r'$$\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}$$',
      r'$$E = mc^2$$',
      r'$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$',
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
                  ...formulas.map(
                    (form) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        form,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.add_rounded,
                        color: colors.primary,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onInsert('\n$form\n');
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

  static void showSymbolSheet(
    BuildContext context, {
    required ValueChanged<String> onInsert,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final symbols = [
      'π', 'θ', 'Δ', 'α', 'β', 'γ', 'λ', 'μ', 'σ', 'ω',
      '≈', '≠', '≤', '≥', '±', '×', '÷', '∞', '√', '∫',
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
                    'Insert Math & Greek Symbol',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: symbols.length,
                    itemBuilder: (ctx, idx) {
                      final sym = symbols[idx];
                      return ShrinkableButton(
                        onTap: () {
                          Navigator.pop(ctx);
                          onInsert(sym);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 25 : 12),
                            borderRadius: BorderRadius.circular(10),
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
