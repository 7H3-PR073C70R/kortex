import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';

/// Status banner indicating on-device neural engine availability.
class OfflineModelStatusCard extends StatelessWidget {
  const OfflineModelStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.success.withAlpha(90),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: colors.success,
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instant On-Device Engine Ready',
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '0MB download required • Pre-indexed concept synthesizer',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(20),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(color: colors.success.withAlpha(50)),
            ),
            child: Text(
              'Active',
              style: typography.caption.bold.copyWith(
                color: colors.success,
                fontSize: 11.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading indicator displayed during neural inference.
class OfflineGeneratingIndicator extends StatelessWidget {
  const OfflineGeneratingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Row(
        children: [
          AppLogoLoader(
            size: 20,
            color: colors.primary,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Running local GGUF Metal/Vulkan neural inference...',
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
