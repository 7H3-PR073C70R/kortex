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
    super.key,
  });

  final FlashcardEntity card;
  final bool isFlipped;
  final VoidCallback onTapFlip;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

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

    // Swipe Offset State for drag gestures
    final dragOffset = useState<Offset>(Offset.zero);
    final isDragging = useState<bool>(false);

    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTapFlip();
      },
      onHorizontalDragStart: (_) {
        isDragging.value = true;
      },
      onHorizontalDragUpdate: (details) {
        dragOffset.value += Offset(details.primaryDelta ?? 0, 0);
      },
      onHorizontalDragEnd: (details) {
        isDragging.value = false;
        final dx = dragOffset.value.dx;
        if (dx < -120) {
          unawaited(HapticFeedback.mediumImpact());
          onSwipeLeft();
        } else if (dx > 120) {
          unawaited(HapticFeedback.mediumImpact());
          onSwipeRight();
        }
        dragOffset.value = Offset.zero;
      },
      child: AnimatedBuilder(
        animation: flipController,
        builder: (context, child) {
          final flipAngle = flipController.value * math.pi;
          final isUnder = flipAngle > math.pi / 2;

          final transformMatrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..multiply(
              Matrix4.translationValues(dragOffset.value.dx, 0, 0),
            )
            ..rotateZ(dragOffset.value.dx * 0.0005)
            ..rotateY(flipAngle);

          return Transform(
            alignment: Alignment.center,
            transform: transformMatrix,
            child: isUnder
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardFace(
                      badgeText: l10n.studySessionBackBadge,
                      badgeColor: const Color(0xFF10B981),
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
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      label: isBackFace
          ? 'Back of card: $mainText. Tap or spacebar to flip.'
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
                    ? const Color(0xFF10B981).withAlpha(isDark ? 120 : 80)
                    : colors.primary.withAlpha(isDark ? 120 : 70),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isBackFace
                      ? const Color(0xFF10B981).withAlpha(isDark ? 40 : 15)
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
                    if (card.sourceTopic != null)
                      Text(
                        card.sourceTopic!,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Center Content (Text + LaTeX Formula)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: LatexCardContentViewer(
                        text: mainText,
                        latexFormula: latexFormula,
                        isBackFace: isBackFace,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom Hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.studySessionTapToFlip,
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
