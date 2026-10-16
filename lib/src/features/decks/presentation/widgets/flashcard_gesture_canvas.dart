import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/text_to_speech_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_drag_route_indicator.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_entrance_widget.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_face_content_resolver.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_face_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Interactive canvas managing 3D flip physics, directional drag gestures,
/// and entrance animations for a study [FlashcardEntity].
class FlashcardGestureCanvas extends HookWidget {
  const FlashcardGestureCanvas({
    required this.card,
    required this.isFlipped,
    required this.onTapFlip,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onOpenParkingLot,
    this.enableBionicReading = false,
    this.ttsService,
    super.key,
  });

  final FlashcardEntity card;
  final bool isFlipped;
  final VoidCallback onTapFlip;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onOpenParkingLot;
  final bool enableBionicReading;
  final TextToSpeechService? ttsService;

  @visibleForTesting
  static (String, String) resolveCardFaces(String front, String back) =>
      CardFaceContentResolver.resolve(front, back);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

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

          final (resolvedFront, resolvedBack) = CardFaceContentResolver.resolve(
            card.front,
            card.back,
          );

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CardEntranceWidget(
                key: ValueKey(card.id),
                child: Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: isUnder
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: CardFaceWidget(
                            badgeText: l10n.studySessionBackBadge,
                            badgeColor: colors.success,
                            mainText: resolvedBack,
                            latexFormula: card.backLatex,
                            isBackFace: true,
                            card: card,
                            enableBionicReading: enableBionicReading,
                            onOpenParkingLot: onOpenParkingLot,
                            ttsService: ttsService,
                          ),
                        )
                      : CardFaceWidget(
                          badgeText: l10n.studySessionFrontBadge,
                          badgeColor: colors.primary,
                          mainText: resolvedFront,
                          latexFormula: card.frontLatex,
                          isBackFace: false,
                          card: card,
                          enableBionicReading: enableBionicReading,
                          onOpenParkingLot: onOpenParkingLot,
                          ttsService: ttsService,
                        ),
                ),
              ),

              // Visual Drag Direction Route Indicator Overlay
              if (routeColor != null && routeLabel != null && routeIcon != null)
                CardDragRouteIndicator(
                  routeColor: routeColor,
                  routeLabel: routeLabel,
                  routeIcon: routeIcon,
                  dragProgress: dragProgress,
                ),
            ],
          );
        },
      ),
    );
  }
}
