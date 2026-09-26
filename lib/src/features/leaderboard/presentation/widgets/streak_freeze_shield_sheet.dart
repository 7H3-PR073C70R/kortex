import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Modal bottom sheet for viewing, acquiring, and equipping streak freeze shields.
class StreakFreezeShieldSheet extends HookWidget {
  const StreakFreezeShieldSheet({super.key});

  static Future<void> show(BuildContext context) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => const StreakFreezeShieldSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final activityService = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>()
        : null;

    final freezeCount = useState<int>(
      activityService?.getStreakFreezes() ?? 1,
    );
    final isBuying = useState<bool>(false);

    Future<void> handlePurchaseFreeze() async {
      AppFeedback.medium();
      isBuying.value = true;
      if (activityService != null) {
        await activityService.purchaseStreakFreeze(costXp: 500);
        freezeCount.value = activityService.getStreakFreezes();
      } else {
        freezeCount.value += 1;
      }
      isBuying.value = false;
      AppFeedback.correct();
      if (context.mounted) {
        context.showSnackBar(
          message: 'Streak Freeze Shield acquired!',
          type: SnackBarType.success,
        );
      }
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: colors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streak Freeze Shield',
                          style: typography.title2.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Protect your study streak if you miss a day',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Shield Inventory Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 40 : 20),
                      colors.syllabotAccent.withAlpha(isDark ? 30 : 15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: colors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Inventory',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${freezeCount.value} Freeze Shield${freezeCount.value == 1 ? "" : "s"} Equipped',
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Text(
                        'PROTECTED',
                        style: typography.caption.bold.copyWith(
                          color: colors.success,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Benefits breakdown
              Text(
                'How Freeze Shields Work:',
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                context,
                icon: Icons.auto_awesome_rounded,
                title: 'Automatic Activation',
                description:
                    'If you miss a 24-hour review window, 1 shield is automatically consumed to preserve your streak integer.',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                context,
                icon: Icons.bolt_rounded,
                title: 'Leaderboard Protection',
                description:
                    'Keeps your XP multiplier intact and protects your weekly league rank.',
              ),
              const SizedBox(height: 24),

              // Action button
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedScale(
                    scale: isHovered ? 1.01 : 1.0,
                    duration: AppMotion.snappy,
                    child: child,
                  );
                },
                child: AppButton(
                  text: isBuying.value
                      ? 'Acquiring Shield...'
                      : 'Acquire Freeze Shield (500 XP)',
                  prefixIcon: Icon(
                    Icons.add_moderator_rounded,
                    size: 18,
                    color: colors.white,
                  ),
                  isLoading: isBuying.value,
                  onPressed: isBuying.value ? null : handlePurchaseFreeze,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
