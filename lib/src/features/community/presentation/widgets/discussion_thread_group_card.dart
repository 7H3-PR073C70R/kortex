import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_actions_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_children_spine.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/parent_reply_author_header.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/parent_reply_content_body.dart';

export 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_actions_bar.dart';
export 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_children_spine.dart';
export 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_options_menu.dart';
export 'package:kortex/src/features/community/presentation/widgets/thread_group/level2_child_reply_card.dart';
export 'package:kortex/src/features/community/presentation/widgets/thread_group/parent_reply_author_header.dart';
export 'package:kortex/src/features/community/presentation/widgets/thread_group/parent_reply_content_body.dart';

/// Discussion Thread Group Card (Level 1 Parent + Level 2 Child Replies with Continuous Spine & Anchor Curves).
class DiscussionThreadGroupCard extends HookWidget {
  const DiscussionThreadGroupCard({
    required this.parentReply,
    required this.children,
    required this.opAuthorName,
    required this.isQuestion,
    required this.isAuthor,
    required this.hasVerifiedSolution,
    required this.isExpanded,
    required this.isLoadingChildren,
    required this.hasMoreChildren,
    required this.onToggleExpand,
    required this.onLoadMoreChildren,
    required this.onVote,
    required this.onChildVote,
    required this.onReplyTap,
    required this.onChildReplyTap,
    required this.onVerifySolution,
    super.key,
    this.highlightReplyId,
    this.onSaveFlashcard,
    this.onEditReply,
    this.onDeleteReply,
    this.onEditChildReply,
    this.onDeleteChildReply,
    this.onTranscriptUpdated,
    this.userStorage,
  });

  final ForumReplyEntity parentReply;
  final List<ForumReplyEntity> children;
  final String? highlightReplyId;
  final String opAuthorName;
  final bool isQuestion;
  final bool isAuthor;
  final bool hasVerifiedSolution;
  final bool isExpanded;
  final bool isLoadingChildren;
  final bool hasMoreChildren;
  final VoidCallback onToggleExpand;
  final VoidCallback onLoadMoreChildren;
  final void Function(int direction) onVote;
  final void Function(ForumReplyEntity child, int direction) onChildVote;
  final VoidCallback onReplyTap;
  final void Function(String replyId, String newTranscript)?
  onTranscriptUpdated;
  final void Function(ForumReplyEntity child) onChildReplyTap;
  final VoidCallback onVerifySolution;
  final void Function(ForumReplyEntity target)? onSaveFlashcard;
  final VoidCallback? onEditReply;
  final VoidCallback? onDeleteReply;
  final void Function(ForumReplyEntity child)? onEditChildReply;
  final void Function(ForumReplyEntity child)? onDeleteChildReply;
  final UserStorageService? userStorage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isHighlighted = parentReply.id == highlightReplyId;
    final isUpvoted = parentReply.userVote == 1;
    final isDownvoted = parentReply.userVote == -1;

    final isAiReply =
        parentReply.authorName.toLowerCase().contains('syllabot') ||
        parentReply.content.contains('🤖') ||
        parentReply.content.contains('Syllabot Socratic Hint');

    final isOp =
        parentReply.authorName.toLowerCase() == opAuthorName.toLowerCase();
    final totalChildCount = math.max(
      parentReply.repliesCount,
      children.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEVEL 1 REPLY CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: isHighlighted
                ? Border.all(color: colors.primary, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? colors.primary.withAlpha(isDark ? 65 : 40)
                    : colors.black.withAlpha(isDark ? 25 : 8),
                blurRadius: isHighlighted ? 12 : 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHighlighted)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Highlighted Reply',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

              // Author Info & Options
              ParentReplyAuthorHeader(
                parentReply: parentReply,
                isAiReply: isAiReply,
                isOp: isOp,
                onEditReply: onEditReply,
                onDeleteReply: onDeleteReply,
                userStorage: userStorage,
              ),
              const SizedBox(height: 10),

              // Body Content & Attachments
              ParentReplyContentBody(
                parentReply: parentReply,
                onTranscriptUpdated: onTranscriptUpdated,
              ),
              const SizedBox(height: 12),

              // Interaction Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ForumReplyActionsBar(
                  parentReply: parentReply,
                  isUpvoted: isUpvoted,
                  isDownvoted: isDownvoted,
                  onVote: onVote,
                  onReplyTap: onReplyTap,
                  totalChildCount: totalChildCount,
                  isQuestion: isQuestion,
                  hasVerifiedSolution: hasVerifiedSolution,
                  isAuthor: isAuthor,
                  onVerifySolution: onVerifySolution,
                  onSaveFlashcard: onSaveFlashcard,
                ),
              ),
            ],
          ),
        ),

        // SUB-REPLIES SECTION (Connecting spine and children stream)
        ForumReplyChildrenSpine(
          totalChildCount: totalChildCount,
          children: children,
          isExpanded: isExpanded,
          isLoadingChildren: isLoadingChildren,
          hasMoreChildren: hasMoreChildren,
          opAuthorName: opAuthorName,
          highlightReplyId: highlightReplyId,
          onToggleExpand: onToggleExpand,
          onLoadMoreChildren: onLoadMoreChildren,
          onChildVote: onChildVote,
          onChildReplyTap: onChildReplyTap,
          onEditChildReply: onEditChildReply,
          onDeleteChildReply: onDeleteChildReply,
          onTranscriptUpdated: onTranscriptUpdated,
          userStorage: userStorage,
        ),
      ],
    );
  }
}
