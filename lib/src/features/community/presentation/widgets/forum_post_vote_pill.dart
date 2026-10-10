import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bidirectional vote pill for the original post card
class ForumPostVotePill extends StatelessWidget {
  const ForumPostVotePill({
    required this.netVotes,
    required this.userVote,
    required this.onUpvote,
    required this.onDownvote,
    super.key,
  });

  final int netVotes;
  final int userVote;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isUpvoted = userVote == 1;
    final isDownvoted = userVote == -1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: isUpvoted
            ? colors.recallEasy.withAlpha(isDark ? 50 : 30)
            : (isDownvoted
                  ? colors.error.withAlpha(isDark ? 50 : 30)
                  : (isDark
                        ? colors.surfacePrimary.withAlpha(160)
                        : colors.surfaceSecondary.withAlpha(120))),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShrinkableButton(
            onTap: onUpvote,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUpvoted ? colors.recallEasy : colors.transparent,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: isUpvoted ? colors.white : colors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$netVotes',
              style: typography.caption.bold.copyWith(
                color: isUpvoted
                    ? colors.recallEasy
                    : (isDownvoted ? colors.error : colors.textPrimary),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ShrinkableButton(
            onTap: onDownvote,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDownvoted ? colors.error : colors.transparent,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDownvoted ? colors.white : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick tool chip in bottom sticky reply bar
class QuickToolChip extends StatelessWidget {
  const QuickToolChip({
    required this.label,
    this.icon,
    this.prefix,
    this.isCodeStyle = false,
    this.isHighlighted = false,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? prefix;
  final bool isCodeStyle;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final tint = isHighlighted ? colors.primary : colors.textSecondary;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedScale(
          scale: isHovered ? 1.04 : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isHighlighted
                ? colors.primary.withAlpha(isDark ? 40 : 25)
                : (isDark
                      ? colors.surfacePrimary.withAlpha(180)
                      : colors.surfaceSecondary.withAlpha(120)),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: isHighlighted
                  ? colors.primary.withAlpha(80)
                  : colors.surfaceBorder.withAlpha(isDark ? 40 : 25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: isCodeStyle
                      ? typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        )
                      : typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                ),
                const SizedBox(width: 4),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: tint,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: isHighlighted ? colors.primary : colors.textPrimary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
