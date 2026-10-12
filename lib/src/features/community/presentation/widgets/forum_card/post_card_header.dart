import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top header for TrackForumPostCard showing the track channel pill,
/// status badges ('Knowledge Gap' / 'Solved'), and more options menu button.
class PostCardHeader extends StatelessWidget {
  const PostCardHeader({
    required this.post,
    required this.onOptionsTap,
    super.key,
  });

  final ForumPostEntity post;
  final VoidCallback onOptionsTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        // Track Channel Pill: [Beacon Dot + c/Track]
        Expanded(
          child: Row(
            children: [
              RepaintBoundary(
                child: AppPulsingBeacon(
                  color: colors.primary,
                  size: 6,
                  pulseSpread: 3,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'c/${post.track}',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Badges & More Button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.isQuestion ||
                post.title.endsWith('?') ||
                post.repliesCount == 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(
                    isDark ? 35 : 20,
                  ),
                  borderRadius: AppRadius.radiusMicro,
                  border: Border.all(
                    color: colors.primary.withAlpha(
                      isDark ? 70 : 40,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Knowledge Gap',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            if (post.isVerifiedSolution)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.success.withAlpha(
                    isDark ? 35 : 20,
                  ),
                  borderRadius: AppRadius.radiusMicro,
                  border: Border.all(
                    color: colors.success.withAlpha(
                      isDark ? 70 : 40,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 11,
                      color: colors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Solved',
                      style: typography.caption.bold.copyWith(
                        color: colors.success,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            PlatformHoverBuilder(
              builder: (context, isMoreHovered, child) => AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                decoration: BoxDecoration(
                  color: isMoreHovered
                      ? colors.surfaceBorder.withAlpha(
                          isDark ? 40 : 25,
                        )
                      : colors.transparent,
                  borderRadius: AppRadius.radiusMicro,
                ),
                child: ShrinkableButton(
                  onTap: onOptionsTap,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: isMoreHovered
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
