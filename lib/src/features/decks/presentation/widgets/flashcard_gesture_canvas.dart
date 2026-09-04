import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';
import 'package:kortex/src/l10n/l10n.dart';

class FlashcardGestureCanvas extends HookWidget {
  const FlashcardGestureCanvas({
    required this.card,
    required this.isFlipped,
    required this.onTapFlip,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    super.key,
  });

  final FlashcardEntity card;
  final bool isFlipped;
  final VoidCallback onTapFlip;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    // Flip Animation Controller
    final flipController = useAnimationController(
      duration: const Duration(milliseconds: 380),
    );

    // Synchronize flip state
    useEffect(
      () {
        if (isFlipped) {
          unawaited(flipController.forward());
        } else {
          unawaited(flipController.reverse());
        }
        return null;
      },
      [isFlipped],
    );

    // Motion Animation Controller for fluid snap-back and swipe fly-off
    final motionController = useAnimationController(
      duration: const Duration(milliseconds: 260),
    );
    final snapStartOffset = useRef<Offset>(Offset.zero);
    final snapTargetOffset = useRef<Offset>(Offset.zero);

    // 2D Swipe Offset State for drag gestures
    final dragOffset = useState<Offset>(Offset.zero);
    final isDragging = useState<bool>(false);

    final dx = dragOffset.value.dx;
    final dy = dragOffset.value.dy;

    // Determine current drag direction for visual route overlay
    Color? routeColor;
    String? routeLabel;
    IconData? routeIcon;
    double dragProgress = 0;

    if (dx.abs() > 30 || dy.abs() > 30) {
      if (dx.abs() >= dy.abs()) {
        if (dx > 0) {
          routeColor = colors.recallGood;
          routeLabel = l10n.studySessionRouteGood(l10n.studyRatingGoodInterval);
          routeIcon = Icons.thumb_up_rounded;
          dragProgress = (dx / 120).clamp(0.0, 1.0);
        } else {
          routeColor = colors.recallHard;
          routeLabel = l10n.studySessionRouteHard(l10n.studyRatingHardInterval);
          routeIcon = Icons.bolt_rounded;
          dragProgress = (dx.abs() / 120).clamp(0.0, 1.0);
        }
      } else {
        if (dy < 0) {
          routeColor = colors.recallEasy;
          routeLabel = l10n.studySessionRouteEasy(l10n.studyRatingEasyInterval);
          routeIcon = Icons.rocket_launch_rounded;
          dragProgress = (dy.abs() / 100).clamp(0.0, 1.0);
        } else {
          routeColor = colors.recallAgain;
          routeLabel = l10n.studySessionRouteAgain(
            l10n.studyRatingAgainInterval,
          );
          routeIcon = Icons.replay_rounded;
          dragProgress = (dy / 100).clamp(0.0, 1.0);
        }
      }
    }

    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTapFlip();
      },
      onPanStart: (_) {
        if (motionController.isAnimating) {
          motionController.stop();
        }
        isDragging.value = true;
      },
      onPanUpdate: (details) {
        dragOffset.value += details.delta;
      },
      onPanEnd: (details) {
        isDragging.value = false;
        final currentDx = dragOffset.value.dx;
        final currentDy = dragOffset.value.dy;
        final velocity = details.velocity.pixelsPerSecond;

        // Velocity & threshold evaluation
        final isFlickLeft = (velocity.dx < -450 && currentDx < -30) || currentDx < -90;
        final isFlickRight = (velocity.dx > 450 && currentDx > 30) || currentDx > 90;
        final isFlickUp = (velocity.dy < -450 && currentDy < -30) || currentDy < -80;
        final isFlickDown = (velocity.dy > 450 && currentDy > 30) || currentDy > 80;

        VoidCallback? swipeCallback;
        var targetOffset = Offset.zero;

        final screenSize = MediaQuery.of(context).size;

        if (currentDx.abs() >= currentDy.abs()) {
          if (isFlickLeft) {
            swipeCallback = onSwipeLeft;
            targetOffset = Offset(-screenSize.width * 1.3, currentDy * 1.2);
          } else if (isFlickRight) {
            swipeCallback = onSwipeRight;
            targetOffset = Offset(screenSize.width * 1.3, currentDy * 1.2);
          }
        } else {
          if (isFlickUp) {
            swipeCallback = onSwipeUp ?? onSwipeRight;
            targetOffset = Offset(currentDx * 1.2, -screenSize.height * 1.1);
          } else if (isFlickDown) {
            swipeCallback = onSwipeDown ?? onSwipeLeft;
            targetOffset = Offset(currentDx * 1.2, screenSize.height * 1.1);
          }
        }

        if (swipeCallback != null) {
          // Animate smoothly off-screen then fire swipe
          unawaited(HapticFeedback.mediumImpact());
          snapStartOffset.value = dragOffset.value;
          snapTargetOffset.value = targetOffset;
          motionController.reset();

          void flyListener() {
            final t = Curves.easeInCubic.transform(motionController.value);
            dragOffset.value = Offset.lerp(
              snapStartOffset.value,
              snapTargetOffset.value,
              t,
            )!;
            if (motionController.isCompleted) {
              motionController.removeListener(flyListener);
              dragOffset.value = Offset.zero;
              swipeCallback!();
            }
          }

          motionController.addListener(flyListener);
          unawaited(motionController.forward());
        } else {
          // Swiped halfway or canceled: smoothly snap back to center with spring curve
          snapStartOffset.value = dragOffset.value;
          snapTargetOffset.value = Offset.zero;
          motionController.reset();

          void snapListener() {
            final t = Curves.easeOutCubic.transform(motionController.value);
            dragOffset.value = Offset.lerp(
              snapStartOffset.value,
              snapTargetOffset.value,
              t,
            )!;
            if (motionController.isCompleted) {
              motionController.removeListener(snapListener);
              dragOffset.value = Offset.zero;
            }
          }

          motionController.addListener(snapListener);
          unawaited(motionController.forward());
        }
      },
      child: AnimatedBuilder(
        animation: flipController,
        builder: (context, child) {
          final flipAngle = flipController.value * math.pi;
          final isUnder = flipAngle > math.pi / 2;

          final transformMatrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..multiply(
              Matrix4.translationValues(
                dragOffset.value.dx,
                dragOffset.value.dy * 0.7,
                0,
              ),
            )
            ..rotateZ(dragOffset.value.dx * 0.0004)
            ..rotateY(flipAngle);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: transformMatrix,
                child: isUnder
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardFace(
                          badgeText: l10n.studySessionBackBadge,
                          badgeColor: colors.success,
                          mainText: card.back,
                          latexFormula: card.backLatex,
                          isBackFace: true,
                          colors: colors,
                          typography: typography,
                          isDark: isDark,
                          card: card,
                        ),
                      )
                    : _CardFace(
                        badgeText: l10n.studySessionFrontBadge,
                        badgeColor: colors.primary,
                        mainText: card.front,
                        latexFormula: card.frontLatex,
                        isBackFace: false,
                        colors: colors,
                        typography: typography,
                        isDark: isDark,
                        card: card,
                      ),
              ),

              // Visual Drag Direction Route Indicator Overlay
              if (routeColor != null && routeLabel != null && routeIcon != null)
                Positioned(
                  top: 24,
                  child: Opacity(
                    opacity: dragProgress,
                    child: Transform.scale(
                      scale: 0.85 + (0.25 * dragProgress),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: routeColor.withAlpha(isDark ? 230 : 255),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: routeColor.withAlpha(120),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(routeIcon, color: colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              routeLabel,
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.badgeText,
    required this.badgeColor,
    required this.mainText,
    required this.isBackFace,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.card,
    this.latexFormula,
  });

  final String badgeText;
  final Color badgeColor;
  final String mainText;
  final String? latexFormula;
  final bool isBackFace;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final FlashcardEntity card;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: isBackFace
          ? 'Back of card: $mainText. Rate recall or tap to flip.'
          : 'Front of card: $mainText. Tap or spacebar to reveal answer.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 340, maxWidth: 640),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  if (isDark)
                    colors.surfaceSecondary.withAlpha(220)
                  else
                    colors.surfacePrimary.withAlpha(245),
                  if (isDark)
                    colors.surfacePrimary.withAlpha(235)
                  else
                    colors.surfaceSecondary.withAlpha(230),
                ],
              ),
              border: Border.all(
                color: isBackFace
                    ? colors.success.withAlpha(isDark ? 120 : 80)
                    : colors.primary.withAlpha(isDark ? 120 : 70),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isBackFace
                      ? colors.success.withAlpha(isDark ? 40 : 15)
                      : colors.primary.withAlpha(isDark ? 50 : 20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(isDark ? 45 : 20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badgeColor.withAlpha(100),
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: typography.caption.bold.copyWith(
                          color: badgeColor,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (card.sourceTopic != null &&
                        (isBackFace || card.sourceTopic != mainText)) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          card.sourceTopic!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Center Content (Text + Image + LaTeX Formula)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: LatexCardContentViewer(
                        text: mainText,
                        latexFormula: latexFormula,
                        imageUrl: card.imageUrl,
                        isBackFace: isBackFace,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom Self-Aware Hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBackFace
                          ? Icons.swap_vert_rounded
                          : Icons.touch_app_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBackFace
                          ? context.l10n.studySessionTapToFlipBack
                          : context.l10n.studySessionTapToFlip,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
