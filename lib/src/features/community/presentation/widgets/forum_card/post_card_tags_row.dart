import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';

/// Tags section for TrackForumPostCard displaying track tags, syllabus topic tags,
/// custom user tags, XP bounty pills, and question tags.
class PostCardTagsRow extends StatelessWidget {
  const PostCardTagsRow({
    required this.post,
    super.key,
  });

  final ForumPostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final badgeColor = isDark
        ? colors.surfacePrimary.withAlpha(160)
        : colors.surfaceSecondary.withAlpha(120);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Track tag
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: AppRadius.radiusBadge,
          ),
          child: Text(
            '#${post.track.toLowerCase()}',
            style: typography.caption.medium.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),

        // Syllabus topic tag
        if (post.syllabusTag.isNotEmpty && post.syllabusTag != 'General')
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: AppRadius.radiusBadge,
            ),
            child: Text(
              '#${post.syllabusTag.replaceAll(' ', '').toLowerCase()}',
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),

        // Custom tags
        if (post.tags.isNotEmpty)
          ...post.tags.map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: AppRadius.radiusBadge,
              ),
              child: Text(
                tag.startsWith('#') ? tag.toLowerCase() : '#${tag.toLowerCase()}',
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ),

        // Karma bounty pill
        if (post.karmaBounty > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: colors.syllabotAccent.withValues(
                alpha: 0.15,
              ),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: colors.syllabotAccent.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: 12,
                  color: colors.syllabotAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '💰 ${post.karmaBounty} XP Bounty',
                  style: typography.caption.bold.copyWith(
                    color: colors.syllabotAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        // Question tag
        if (post.isQuestion)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: AppRadius.radiusBadge,
            ),
            child: Text(
              '#question',
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
