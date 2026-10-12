import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/subject_master_badge.dart';

/// Formats a timestamp into a human-readable relative time string.
String formatPostCardTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// Author row for TrackForumPostCard showing the author's avatar with online status,
/// username, subject master or incognito badge, XP bounty, and relative creation time.
class PostCardAuthorRow extends StatelessWidget {
  const PostCardAuthorRow({
    required this.post,
    super.key,
  });

  final ForumPostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        if (post.isAnonymous)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceBorder.withAlpha(40),
              border: Border.all(
                color: colors.textSecondary.withAlpha(
                  isDark ? 50 : 30,
                ),
              ),
            ),
            child: Icon(
              Icons.visibility_off_rounded,
              size: 16,
              color: colors.textSecondary,
            ),
          )
        else
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: colors.primary.withAlpha(
                  isDark ? 50 : 30,
                ),
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : 'U',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.success,
                    border: Border.all(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(width: 10),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  post.isAnonymous
                      ? post.authorName
                      : '@${post.authorName}',
                  style: typography.caption.bold.copyWith(
                    color: post.isAnonymous
                        ? colors.textSecondary
                        : colors.textPrimary,
                    fontSize: 13,
                    fontStyle: post.isAnonymous
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (post.isAnonymous)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withAlpha(
                      isDark ? 35 : 20,
                    ),
                    borderRadius: AppRadius.radiusMicro,
                    border: Border.all(
                      color: colors.textSecondary.withAlpha(
                        isDark ? 60 : 35,
                      ),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 9,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Incognito',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SubjectMasterBadge(
                  track: post.track,
                  compact: true,
                ),
              if (post.isQuestion) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withAlpha(
                      isDark ? 35 : 20,
                    ),
                    borderRadius: AppRadius.radiusMicro,
                  ),
                  child: Text(
                    '+${post.karmaBounty > 0 ? post.karmaBounty : 100} XP',
                    style: typography.caption.bold.copyWith(
                      color: colors.warning,
                      fontSize: 9.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '•',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatPostCardTime(post.createdAt),
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
