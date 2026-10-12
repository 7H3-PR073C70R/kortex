import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interaction row for top-level parent forum reply:
/// vote pill, reply count button, mark solved bounty action, save to flashcard button.
class ForumReplyActionsBar extends StatelessWidget {
  const ForumReplyActionsBar({
    required this.parentReply,
    required this.isUpvoted,
    required this.isDownvoted,
    required this.onVote,
    required this.onReplyTap,
    required this.totalChildCount,
    required this.isQuestion,
    required this.hasVerifiedSolution,
    required this.isAuthor,
    required this.onVerifySolution,
    this.onSaveFlashcard,
    super.key,
  });

  final ForumReplyEntity parentReply;
  final bool isUpvoted;
  final bool isDownvoted;
  final void Function(int direction) onVote;
  final VoidCallback onReplyTap;
  final int totalChildCount;
  final bool isQuestion;
  final bool hasVerifiedSolution;
  final bool isAuthor;
  final VoidCallback onVerifySolution;
  final void Function(ForumReplyEntity target)? onSaveFlashcard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Vote Pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary.withAlpha(160)
                  : colors.surfaceSecondary.withAlpha(120),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShrinkableButton(
                  onTap: () => onVote(1),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: isUpvoted
                          ? colors.recallEasy
                          : colors.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    parentReply.netVotes > 0
                        ? '+${parentReply.netVotes}'
                        : '${parentReply.netVotes}',
                    style: typography.caption.bold.copyWith(
                      color: isUpvoted
                          ? colors.recallEasy
                          : (isDownvoted
                                ? colors.error
                                : colors.recallEasy),
                      fontSize: 12,
                    ),
                  ),
                ),
                ShrinkableButton(
                  onTap: () => onVote(-1),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDownvoted
                          ? colors.error
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Reply Button
          ShrinkableButton(
            onTap: onReplyTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary.withAlpha(120)
                    : colors.surfaceSecondary.withAlpha(80),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalChildCount > 0
                        ? 'Reply ($totalChildCount)'
                        : 'Reply',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Solution Verification Button if Bounty
          if (isQuestion &&
              !parentReply.isVerifiedSolution &&
              (!hasVerifiedSolution || isAuthor)) ...[
            const SizedBox(width: 8),
            ShrinkableButton(
              onTap: onVerifySolution,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.warning.withAlpha(isDark ? 30 : 18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.warning.withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 12,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mark Solved',
                      style: typography.caption.bold.copyWith(
                        color: colors.warning,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Save Solution to Flashcard Button
          const SizedBox(width: 8),
          ShrinkableButton(
            onTap: () => onSaveFlashcard?.call(parentReply),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 30 : 18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withAlpha(60),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 12,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Save Flashcard',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
