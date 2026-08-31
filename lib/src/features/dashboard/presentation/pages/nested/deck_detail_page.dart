import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
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
          ? const Color(0xFF090D16)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back to Dashboard',
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => context.router.pop(),
          ),
        ),
        title: Text(
          'Active Recall Session',
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
                    'Card ${currentCardIndex.value + 1} of ${mockCards.length}',
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
                      'SM-2 SPATIAL QUEUE',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (currentCardIndex.value + 1) / mockCards.length,
                  backgroundColor: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(50)
                      : colors.surfaceBorder.withAlpha(100),
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 24),

              // Interactive Flashcard Flip
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    isFlipped.value = !isFlipped.value;
                  },
                  child: Semantics(
                    button: true,
                    label: isFlipped.value
                        ? 'Flashcard back: '
                              '${mockCards[currentCardIndex.value].back}. '
                              'Tap to flip.'
                        : 'Flashcard front: '
                              '${mockCards[currentCardIndex.value].front}. '
                              'Tap to reveal answer.',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(200)
                                : colors.surfacePrimary.withAlpha(240),
                            border: Border.all(
                              color: isFlipped.value
                                  ? colors.syllabotAccent.withAlpha(140)
                                  : (isDark
                                        ? colors.surfaceBorderHighlight
                                              .withAlpha(80)
                                        : colors.surfaceBorder.withAlpha(140)),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 60 : 15),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
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
                                      ? const Color(
                                          0xFF10B981,
                                        ).withAlpha(isDark ? 50 : 25)
                                      : colors.primary.withAlpha(
                                          isDark ? 50 : 25,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isFlipped.value
                                      ? 'ANSWER / FORMULA'
                                      : 'QUESTION',
                                  style: typography.caption.bold.copyWith(
                                    color: isFlipped.value
                                        ? const Color(0xFF10B981)
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
                                'Tap card to flip',
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
                        label: 'Hard',
                        interval: '1d',
                        color: const Color(0xFFEF4444),
                        onTap: () {
                          if (currentCardIndex.value < mockCards.length - 1) {
                            currentCardIndex.value++;
                            isFlipped.value = false;
                          } else {
                            context.router.pop();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Sm2RatingButton(
                        label: 'Good',
                        interval: '3d',
                        color: colors.primary,
                        onTap: () {
                          if (currentCardIndex.value < mockCards.length - 1) {
                            currentCardIndex.value++;
                            isFlipped.value = false;
                          } else {
                            context.router.pop();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Sm2RatingButton(
                        label: 'Easy',
                        interval: '7d',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          if (currentCardIndex.value < mockCards.length - 1) {
                            currentCardIndex.value++;
                            isFlipped.value = false;
                          } else {
                            context.router.pop();
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
      label: 'Rate card as $label, review interval $interval',
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
