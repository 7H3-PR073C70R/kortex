import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';

/// Progress card displaying daily free tier upload limit usage.
class FreeDailyUploadsCard extends StatelessWidget {
  const FreeDailyUploadsCard({
    required this.subscriptionGuard,
    super.key,
  });

  final SubscriptionGuard subscriptionGuard;

  @override
  Widget build(BuildContext context) {
    if (subscriptionGuard.isPro) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final used = subscriptionGuard.getTodayUploadCount();
    const limit = SubscriptionGuard.freeDailyUploadLimit;
    final progress = (used / limit).clamp(0.0, 1.0);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(
          isDark ? 160 : 200,
        ),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Free Daily Uploads',
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '$used / $limit used today',
                style: typography.caption.bold.copyWith(
                  color: progress >= 1.0
                      ? colors.warning
                      : colors.primary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colors.surfaceBorder.withAlpha(50),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? colors.warning
                    : colors.primary,
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
