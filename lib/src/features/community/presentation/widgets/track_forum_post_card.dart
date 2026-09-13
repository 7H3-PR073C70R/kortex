import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class TrackForumPostCard extends StatelessWidget {
  const TrackForumPostCard({
    required this.post,
    required this.onTap,
    this.onUpvoteTap,
    this.onDownvoteTap,
    super.key,
  });

  final ForumPostEntity post;
  final VoidCallback onTap;
  final VoidCallback? onUpvoteTap;
  final VoidCallback? onDownvoteTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isUpvoted = post.userVote == 1;
    final isDownvoted = post.userVote == -1;

    final semanticsLabel =
        'Forum Post: ${post.title}, Track: ${post.track}, '
        'By ${post.authorName}, Score: ${post.netVotes}';

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
            color: post.isVerifiedSolution
                ? colors.success.withAlpha(isDark ? 100 : 70)
                : colors.primary.withAlpha(isDark ? 40 : 25),
            width: post.isVerifiedSolution ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 50 : 15),
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
              // Badges row: Track + Question/Verified Status + Author
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      if (post.isQuestion) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: post.isVerifiedSolution
                                ? colors.success.withAlpha(30)
                                : colors.warning.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                post.isVerifiedSolution
                                    ? Icons.check_circle_rounded
                                    : Icons.help_outline_rounded,
                                size: 12,
                                color: post.isVerifiedSolution
                                    ? colors.success
                                    : colors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post.isVerifiedSolution ? 'Solved' : 'Question',
                                style: typography.caption.bold.copyWith(
                                  color: post.isVerifiedSolution
                                      ? colors.success
                                      : colors.warning,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
              Builder(
                builder: (context) {
                  var snippet = post.content;
                  if (snippet.contains('**Question:**')) {
                    final parts = snippet.split('**Question:**');
                    if (parts.length > 1) snippet = parts[1];
                  } else if (snippet.startsWith('Question:')) {
                    snippet = snippet.substring(9);
                  }
                  if (snippet.contains('**Options:**')) {
                    snippet = snippet.split('**Options:**').first;
                  } else if (snippet.contains('Options:')) {
                    snippet = snippet.split('Options:').first;
                  }
                  snippet = snippet.trim();
                  if (snippet.isEmpty) snippet = post.content;

                  return LatexRichViewer(
                    text: snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  );
                },
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

              // Bottom Stats: Bidirectional Upvote/Downvote Pill and Replies count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Stack Overflow style bidirectional vote capsule
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isUpvoted || isDownvoted)
                              ? (isUpvoted
                                  ? colors.primary.withAlpha(isDark ? 35 : 20)
                                  : colors.error.withAlpha(isDark ? 35 : 20))
                              : (isDark
                                  ? colors.surfacePrimary
                                  : colors.surfaceSecondary.withAlpha(150)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isUpvoted || isDownvoted)
                                ? (isUpvoted
                                    ? colors.primary.withAlpha(120)
                                    : colors.error.withAlpha(120))
                                : colors.primary.withAlpha(isDark ? 30 : 15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShrinkableButton(
                              onTap: onUpvoteTap == null
                                  ? null
                                  : () {
                                      unawaited(HapticFeedback.selectionClick());
                                      onUpvoteTap!();
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 20,
                                  color: isUpvoted
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${post.netVotes}',
                              style: typography.caption.bold.copyWith(
                                color: isUpvoted
                                    ? colors.primary
                                    : isDownvoted
                                        ? colors.error
                                        : colors.textPrimary,
                                fontSize: 12.5,
                              ),
                            ),
                            ShrinkableButton(
                              onTap: onDownvoteTap == null
                                  ? null
                                  : () {
                                      unawaited(HapticFeedback.selectionClick());
                                      onDownvoteTap!();
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: isDownvoted
                                      ? colors.error
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Builder(
                            builder: (context) {
                              final count = post.topLevelRepliesCount;
                              return Text(
                                count == 1 ? '1 reply' : '$count replies',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              );
                            },
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
