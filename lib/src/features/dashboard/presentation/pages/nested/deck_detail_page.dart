import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class DeckDetailPage extends HookWidget {
  const DeckDetailPage({
    @PathParam('deckId') required this.deckId,
    super.key,
  });

  final String deckId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final currentCardIndex = useState<int>(0);

    final mockCards = [
      (
        front:
            'What is the definition of Laplace Transform of a function f(t)?',
        back: 'L{f(t)} = F(s) = ∫[0 to ∞] e^(-st) f(t) dt for s > 0',
      ),
      (
        front: 'State the Fourier Transform inversion theorem.',
        back: 'f(t) = (1/2π) ∫[-∞ to ∞] F(ω) e^(iωt) dω',
      ),
      (
        front:
            'What does the Convolution Theorem state for Laplace Transforms?',
        back: 'L{f(t) * g(t)} = F(s) · G(s)',
      ),
    ];

    final isFlipped = useState<bool>(false);

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.deckDetailBackSemantics,
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => context.router.pop(),
          ),
        ),
        title: Text(
          l10n.deckDetailTitle,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Progress Tracker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.deckDetailCardProgress(
                      currentCardIndex.value + 1,
                      mockCards.length,
                    ),
                    style: typography.footnote.bold.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.deckDetailSm2QueueBadge,
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Flashcard Surface
              Expanded(
                child: Semantics(
                  button: true,
                  label: isFlipped.value
                      ? mockCards[currentCardIndex.value].back
                      : mockCards[currentCardIndex.value].front,
                  child: InkWell(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      isFlipped.value = !isFlipped.value;
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(200)
                                : colors.surfacePrimary.withAlpha(220),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isFlipped.value
                                  ? colors.success.withAlpha(isDark ? 90 : 50)
                                  : colors.primary.withAlpha(isDark ? 80 : 40),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isFlipped.value
                                    ? colors.success.withAlpha(25)
                                    : colors.primary.withAlpha(25),
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
                                  color: isFlipped.value
                                      ? colors.success.withAlpha(
                                          isDark ? 50 : 25,
                                        )
                                      : colors.primary.withAlpha(
                                          isDark ? 50 : 25,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isFlipped.value
                                      ? l10n.deckDetailAnswerFormula
                                      : l10n.deckDetailQuestion,
                                  style: typography.caption.bold.copyWith(
                                    color: isFlipped.value
                                        ? colors.success
                                        : colors.primary,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                isFlipped.value
                                    ? mockCards[currentCardIndex.value].back
                                    : mockCards[currentCardIndex.value].front,
                                textAlign: TextAlign.center,
                                style: typography.title2.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 19,
                                  height: 1.4,
                                ),
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
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // SM-2 Rating Buttons (Hard / Good / Easy)
              if (isFlipped.value) ...[
                Row(
                  children: [
                    Expanded(
                      child: _Sm2RatingButton(
                        label: l10n.deckDetailHard,
                        interval: '1d',
                        color: colors.error,
                        onTap: () {
                          if (currentCardIndex.value < mockCards.length - 1) {
                            currentCardIndex.value++;
                            isFlipped.value = false;
                          } else {
                            unawaited(context.router.maybePop());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Sm2RatingButton(
                        label: l10n.deckDetailGood,
                        interval: '3d',
                        color: colors.primary,
                        onTap: () {
                          if (currentCardIndex.value < mockCards.length - 1) {
                            currentCardIndex.value++;
                            isFlipped.value = false;
                          } else {
                            unawaited(context.router.maybePop());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Sm2RatingButton(
                        label: l10n.deckDetailEasy,
                        interval: '7d',
                        color: colors.success,
                        onTap: () {
                          if (currentCardIndex.value < mockCards.length - 1) {
                            currentCardIndex.value++;
                            isFlipped.value = false;
                          } else {
                            unawaited(context.router.maybePop());
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Sm2RatingButton extends StatelessWidget {
  const _Sm2RatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String interval;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Semantics(
      button: true,
      label: '$label, $interval',
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(120), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                interval,
                style: typography.footnote.regular.copyWith(
                  color: color.withAlpha(200),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
