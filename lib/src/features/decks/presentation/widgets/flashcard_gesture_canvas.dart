import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
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
    this.enableBionicReading = false,
    super.key,
  });

  final FlashcardEntity card;
  final bool isFlipped;
  final VoidCallback onTapFlip;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final bool enableBionicReading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    // Flip Animation Controller with expressive Kowalski curve
    final flipController = useAnimationController(
      duration: AppMotion.expressive,
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
      duration: AppMotion.standard,
    );

    // 2D Swipe Offset State for drag gestures
    final dragOffset = useState<Offset>(Offset.zero);
    final isDragging = useState<bool>(false);

    // Reset motion & gesture state when card ID changes to prevent ghost flickering
    useEffect(
      () {
        dragOffset.value = Offset.zero;
        if (motionController.isAnimating) {
          motionController.stop();
        }
        motionController.reset();
        return null;
      },
      [card.id],
    );
    final snapStartOffset = useRef<Offset>(Offset.zero);
    final snapTargetOffset = useRef<Offset>(Offset.zero);

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
          routeLabel = l10n.studyRatingGood;
          routeIcon = Icons.thumb_up_rounded;
          dragProgress = (dx / 150).clamp(0.0, 1.0);
        } else {
          routeColor = colors.recallHard;
          routeLabel = l10n.studyRatingHard;
          routeIcon = Icons.bolt_rounded;
          dragProgress = (dx.abs() / 150).clamp(0.0, 1.0);
        }
      } else {
        if (dy < 0) {
          routeColor = colors.recallEasy;
          routeLabel = l10n.studyRatingEasy;
          routeIcon = Icons.rocket_launch_rounded;
          dragProgress = (dy.abs() / 120).clamp(0.0, 1.0);
        } else {
          routeColor = colors.recallAgain;
          routeLabel = l10n.studyRatingAgain;
          routeIcon = Icons.replay_rounded;
          dragProgress = (dy / 120).clamp(0.0, 1.0);
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
        final screenSize = MediaQuery.of(context).size;

        final horizontalThreshold = screenSize.width * 0.42;
        final verticalThreshold = screenSize.height * 0.35;

        // Velocity & threshold evaluation: must cross 42% screen width or be a strong intentional flick (> 700 px/s)
        final isFlickLeft =
            (velocity.dx < -700 && currentDx < -screenSize.width * 0.2) ||
            currentDx < -horizontalThreshold;
        final isFlickRight =
            (velocity.dx > 700 && currentDx > screenSize.width * 0.2) ||
            currentDx > horizontalThreshold;
        final isFlickUp =
            (velocity.dy < -700 && currentDy < -screenSize.height * 0.15) ||
            currentDy < -verticalThreshold;
        final isFlickDown =
            (velocity.dy > 700 && currentDy > screenSize.height * 0.15) ||
            currentDy > verticalThreshold;

        VoidCallback? swipeCallback;
        var targetOffset = Offset.zero;

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
              swipeCallback!();
            }
          }

          motionController.addListener(flyListener);
          unawaited(motionController.forward());
        } else {
          // Swiped halfway or less / canceled: smoothly snap back to center with spring curve
          snapStartOffset.value = dragOffset.value;
          snapTargetOffset.value = Offset.zero;
          motionController.reset();

          void snapListener() {
            final t = Curves.easeOutBack.transform(motionController.value);
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
          final smoothT = Curves.easeInOutCubic.transform(flipController.value);
          final flipAngle = smoothT * math.pi;
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

          final (resolvedFront, resolvedBack) = resolveCardFaces(
            card.front,
            card.back,
          );

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Each incoming card rises from the deck: scale 0.96 + fade,
              // keyed by card id so only genuine card changes replay it.
              _CardEntrance(
                key: ValueKey(card.id),
                child: Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: isUnder
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _CardFace(
                            badgeText: l10n.studySessionBackBadge,
                            badgeColor: colors.success,
                            mainText: resolvedBack,
                            latexFormula: card.backLatex,
                            isBackFace: true,
                            colors: colors,
                            typography: typography,
                            isDark: isDark,
                            card: card,
                            enableBionicReading: enableBionicReading,
                          ),
                        )
                      : _CardFace(
                          badgeText: l10n.studySessionFrontBadge,
                          badgeColor: colors.primary,
                          mainText: resolvedFront,
                          latexFormula: card.frontLatex,
                          isBackFace: false,
                          colors: colors,
                          typography: typography,
                          isDark: isDark,
                          card: card,
                          enableBionicReading: enableBionicReading,
                        ),
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
                          borderRadius: BorderRadius.circular(AppRadius.dialog),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(isDark ? 60 : 30),
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

  @visibleForTesting
  static (String, String) resolveCardFaces(String front, String back) {
    // 1. If front already explicitly contains options, nothing to migrate
    final hasFrontOptions = RegExp(
      r'(?:\*\*Options:\*\*|Options:|\n\s*•\s*[A-Ea-e][\.\)])',
      caseSensitive: false,
    ).hasMatch(front);

    if (hasFrontOptions) {
      return (front, back);
    }

    // 2. Check if back contains legacy options block
    final legacyOptionsRegex = RegExp(
      r'(?:\*\*Options:\*\*|Options:)\s*\n([\s\S]*?)(?=\n+\s*(?:\*\*)?(?:Correct Answer|Ans|Answer|Explanation):|\Z)',
      caseSensitive: false,
    );

    final match = legacyOptionsRegex.firstMatch(back);
    if (match == null) {
      return (front, back);
    }

    final rawOptions = match.group(1) ?? '';
    final cleanOptionLines = <String>[];
    String? correctOptionText;

    for (final rawLine in rawOptions.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final isChecked = trimmed.contains('✅');
      final cleaned = trimmed
          .replaceAll('✅', '')
          .replaceAll('•', '')
          .replaceAll('*', '')
          .replaceAll('-', '')
          .trim();

      // Normalize duplicate prefixes like "A. A. Option Text" -> "A. Option Text"
      final optMatch = RegExp(
        r'^(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*(?:(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*)?(.*)',
      ).firstMatch(cleaned);

      if (optMatch != null) {
        final letter = (optMatch.group(1) ?? optMatch.group(2) ?? '')
            .toUpperCase();
        final content = optMatch.group(5)?.trim() ?? '';
        cleanOptionLines.add('• $letter. $content');
        if (isChecked && content.isNotEmpty) {
          correctOptionText = 'Option $letter — $content';
        }
      } else {
        cleanOptionLines.add('• $cleaned');
      }
    }

    final resolvedFront = cleanOptionLines.isNotEmpty
        ? '${front.trim()}\n\n**Options:**\n${cleanOptionLines.join('\n')}'
        : front;

    var resolvedBack =
        (back.substring(0, match.start) + back.substring(match.end)).trim();

    if (correctOptionText != null) {
      resolvedBack = resolvedBack.replaceAllMapped(
        RegExp(
          r'((?:\*\*)?Correct Answer:(?:\*\*)?\s*Option\s+[A-Ea-e])(?!\s*—)',
          caseSensitive: false,
        ),
        (m) => '${m.group(1)} — ${correctOptionText!.split(' — ').last}',
      );
    }

    return (resolvedFront, resolvedBack);
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
    this.enableBionicReading = false,
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
  final bool enableBionicReading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: isBackFace
          ? 'Back of card: $mainText. Rate recall or tap to flip.'
          : 'Front of card: $mainText. Tap or spacebar to reveal answer.',
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Faint deck edges peeking behind the active card — layered
          // solid surfaces instead of blur, cheap during long sessions.
          Positioned(
            left: 20,
            right: 20,
            top: 16,
            bottom: -10,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withAlpha(isDark ? 110 : 150),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(color: colors.surfaceBorder.withAlpha(70)),
              ),
            ),
          ),
          Positioned(
            left: 36,
            right: 36,
            top: 26,
            bottom: -20,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withAlpha(isDark ? 60 : 90),
                borderRadius: BorderRadius.circular(AppRadius.panel),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 340, maxWidth: 640),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
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
                  color: colors.black.withAlpha(isDark ? 60 : 25),
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
                        borderRadius: BorderRadius.circular(AppRadius.badge),
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
                      physics: const ClampingScrollPhysics(),
                      child: LatexCardContentViewer(
                        text: mainText,
                        latexFormula: latexFormula,
                        imageUrl: card.imageUrl,
                        isBackFace: isBackFace,
                        enableBionicReading: enableBionicReading,
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
        ],
      ),
    );
  }
}

/// Brief "rising from the deck" entrance (scale 0.96 + fade), replayed
/// whenever the parent hands in a new card via [ValueKey].
class _CardEntrance extends StatefulWidget {
  const _CardEntrance({required this.child, super.key});

  final Widget child;

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  bool _entranceQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceQueued) return;
    _entranceQueued = true;
    if (!context.reduceMotion) {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuint,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: widget.child,
      ),
    );
  }
}
