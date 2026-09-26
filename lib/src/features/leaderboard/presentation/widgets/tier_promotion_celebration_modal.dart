import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Celebratory modal dialog presented when a user advances to a higher league tier.
class TierPromotionCelebrationModal extends StatelessWidget {
  const TierPromotionCelebrationModal({
    required this.previousTier,
    required this.newTier,
    required this.bonusXp,
    super.key,
  });

  final String previousTier;
  final String newTier;
  final int bonusXp;

  static Future<void> show(
    BuildContext context, {
    required String previousTier,
    required String newTier,
    required int bonusXp,
  }) {
    AppFeedback.heavy();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TierPromotionCelebrationModal(
        previousTier: previousTier,
        newTier: newTier,
        bonusXp: bonusXp,
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return const Color(0xFF00E5FF);
      case 'platinum':
        return const Color(0xFFE0E0E0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final tierColor = _getTierColor(newTier);

    return Dialog(
      backgroundColor: colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            border: Border.all(
              color: tierColor.withAlpha(120),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: tierColor.withAlpha(50),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Icon Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tierColor.withAlpha(100),
                      tierColor.withAlpha(20),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 44,
                    color: tierColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'PROMOTED!',
                style: typography.title1.bold.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: 1.2,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You advanced from $previousTier to $newTier League!',
                textAlign: TextAlign.center,
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // Rewards Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  border: Border.all(
                    color: colors.primary.withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Promotion Bonus: +$bonusXp XP',
                      style: typography.body.bold.copyWith(
                        color: colors.primary,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action button
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedScale(
                    scale: isHovered ? 1.02 : 1.0,
                    duration: AppMotion.snappy,
                    child: child,
                  );
                },
                child: AppButton(
                  text: 'Claim Reward & Continue',
                  onPressed: () {
                    AppFeedback.correct();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
