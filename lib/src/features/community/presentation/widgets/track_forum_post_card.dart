import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class TrackForumPostCard extends StatelessWidget {
  const TrackForumPostCard({
    required this.post,
    required this.onTap,
    this.onUpvoteTap,
    super.key,
  });

  final ForumPostEntity post;
  final VoidCallback onTap;
  final VoidCallback? onUpvoteTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final semanticsLabel =
        'Forum Post: ${post.title}, Track: ${post.track}, '
        'By ${post.authorName}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Track chip + Author
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.track,
                      style: typography.caption.bold.copyWith(
                        color: colors.syllabotAccent,
                      ),
                    ),
                  ),
                  Text(
                    'by ${post.authorName}',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                post.title,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Content snippet
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),

              // LaTeX Formula Preview if present
              if (post.latexContent != null &&
                  post.latexContent!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary.withAlpha(180)
                        : colors.surfaceSecondary.withAlpha(120),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    post.latexContent!,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Bottom Stats: Upvotes and Replies count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ShrinkableButton(
                        onTap: onUpvoteTap ?? () {},
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.upvotes}',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.repliesCount} replies',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
