import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';

/// 3D Flipping flashcard component in InRoomDeckStudyWorkspace.
class WorkspaceInteractiveFlashcard extends StatelessWidget {
  const WorkspaceInteractiveFlashcard({
    required this.card,
    required this.flipAnimation,
    required this.onFlipTap,
    super.key,
  });

  final FlashcardEntity card;
  final Animation<double> flipAnimation;
  final VoidCallback onFlipTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFlipTap,
      child: AnimatedBuilder(
        animation: flipAnimation,
        builder: (context, child) {
          final angle = flipAnimation.value * math.pi;
          final isUnder = angle > math.pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: WorkspaceCardFace(
                      title: 'ANSWER / EXPLANATION',
                      content: card.back,
                      isBack: true,
                    ),
                  )
                : WorkspaceCardFace(
                    title: 'QUESTION / PROMPT',
                    content: card.front,
                    isBack: false,
                  ),
          );
        },
      ),
    );
  }
}

/// Single face of the flashcard (Front prompt or Back answer).
class WorkspaceCardFace extends StatelessWidget {
  const WorkspaceCardFace({
    required this.title,
    required this.content,
    required this.isBack,
    super.key,
  });

  final String title;
  final String content;
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBack
              ? colors.primary.withAlpha(isDark ? 120 : 80)
              : colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
          width: isBack ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 70 : 15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isBack
                      ? colors.recallEasy.withAlpha(isDark ? 40 : 25)
                      : colors.primary.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBack ? Icons.check_circle_outline : Icons.help_outline,
                      size: 13,
                      color: isBack ? colors.recallEasy : colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      title,
                      style: typography.caption.bold.copyWith(
                        color: isBack ? colors.recallEasy : colors.primary,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to flip',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: LatexCardContentViewer(
                  text: content,
                  isBackFace: isBack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
