import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Interactive flashcard preview surface that flips between question (front) and answer (back).
class FlashcardSurface extends StatelessWidget {
  const FlashcardSurface({
    required this.isFlipped,
    required this.card,
    required this.onFlip,
    super.key,
  });

  final bool isFlipped;
  final FlashcardEntity card;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final displayText = isFlipped ? card.back : card.front;
    final displayLatex = isFlipped ? card.backLatex : card.frontLatex;

    return Semantics(
      button: true,
      label: displayText,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return InkWell(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onFlip();
            },
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(200)
                        : colors.surfacePrimary.withAlpha(220),
                    borderRadius: BorderRadius.circular(AppRadius.dialog),
                    border: Border.all(
                      color: isFlipped
                          ? colors.success.withAlpha(isDark ? 90 : 50)
                          : isHovered
                              ? colors.primary.withAlpha(isDark ? 140 : 80)
                              : colors.primary.withAlpha(isDark ? 80 : 40),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 50 : 20),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFlipped
                              ? colors.success.withAlpha(isDark ? 50 : 25)
                              : colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(AppRadius.micro),
                        ),
                        child: Text(
                          isFlipped
                              ? l10n.deckDetailAnswerFormula
                              : l10n.deckDetailQuestion,
                          style: typography.caption.bold.copyWith(
                            color: isFlipped ? colors.success : colors.primary,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      LatexCardContentViewer(
                        text: displayText,
                        latexFormula: displayLatex,
                        imageUrl: card.imageUrl,
                        isBackFace: isFlipped,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.deckDetailTapToFlip,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
