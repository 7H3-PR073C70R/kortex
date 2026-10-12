import 'package:flutter/material.dart';
import 'package:kortex/src/core/constants/app_spacing.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Storage & AI Cache Management section.
class SecurityStorageCacheSection extends StatelessWidget {
  const SecurityStorageCacheSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SecuritySectionContainer(
      title: 'Storage & AI Cache Management',
      subtitle: 'Free up local device memory without losing study data',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Syllabot & Image Cache',
                  style: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  'Temporary audio, token & image buffers',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalSpaceSmall,
          PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return AnimatedScale(
                scale: isHovered ? 1.04 : 1.0,
                duration: AppMotion.snappy,
                curve: Curves.easeOutCubic,
                child: child,
              );
            },
            child: ShrinkableButton(
              onTap: () {
                AppFeedback.light();
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                context.showSnackBar(
                  message: 'Local memory and image cache cleared!',
                  type: SnackBarType.success,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: colors.primary.withAlpha(80),
                  ),
                ),
                child: Text(
                  'Clear Cache',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
