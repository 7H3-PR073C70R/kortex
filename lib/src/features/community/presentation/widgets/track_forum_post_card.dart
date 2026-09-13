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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: post.isVerifiedSolution
                ? colors.success.withAlpha(isDark ? 60 : 40)
                : colors.primary.withAlpha(isDark ? 20 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reddit-style Metadata Header: [Track Pill] • u/author • time • badges
                  Row(
                    children: [
                      // Track Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 35 : 20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.track,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Dot separator
                      Text(
                        '•',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Author
                      Flexible(
                        child: Text(
                          'u/${post.authorName}',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Dot separator
                      Text(
                        '•',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Time
                      Text(
                        _formatTime(post.createdAt),
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary.withAlpha(180),
                          fontSize: 11.5,
                        ),
                      ),

                      // Status Flares (Solved / Bounty)
                      if (post.isVerifiedSolution) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.success.withAlpha(isDark ? 30 : 20),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 11,
                                color: colors.success,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Solved',
                                style: typography.caption.bold.copyWith(
                                  color: colors.success,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (post.isQuestion) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withAlpha(isDark ? 30 : 18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 11,
                                color: colors.warning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '+100 XP',
                                style: typography.caption.bold.copyWith(
                                  color: colors.warning,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Post Title
                  Text(
                    post.title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Post Content Snippet
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
                          height: 1.4,
                        ),
                      );
                    },
                  ),

                  // LaTeX Formula Preview if present
                  if (post.latexContent != null &&
                      post.latexContent!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfacePrimary.withAlpha(160)
                            : colors.surfaceSecondary.withAlpha(100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        post.latexContent!,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Reddit-style Bottom Action Bar
                  Row(
                    children: [
                      // Matte Bidirectional Vote Capsule
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: (isUpvoted || isDownvoted)
                              ? (isUpvoted
                                  ? colors.primary.withAlpha(isDark ? 30 : 18)
                                  : colors.error.withAlpha(isDark ? 30 : 18))
                              : (isDark
                                  ? colors.surfacePrimary.withAlpha(180)
                                  : colors.surfaceSecondary.withAlpha(120)),
                          borderRadius: BorderRadius.circular(16),
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
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  right: 4,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 18,
                                  color: isUpvoted
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${post.netVotes}',
                                style: typography.caption.bold.copyWith(
                                  color: isUpvoted
                                      ? colors.primary
                                      : isDownvoted
                                          ? colors.error
                                          : colors.textPrimary,
                                  fontSize: 12,
                                ),
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
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  right: 8,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: isDownvoted
                                      ? colors.error
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Comments Pill
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfacePrimary.withAlpha(180)
                              : colors.surfaceSecondary.withAlpha(120),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
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
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (post.syllabusTag.isNotEmpty &&
                          post.syllabusTag != 'General') ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: colors.syllabotAccent.withAlpha(isDark ? 25 : 15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 13,
                                  color: colors.syllabotAccent,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    post.syllabusTag,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.syllabotAccent,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
