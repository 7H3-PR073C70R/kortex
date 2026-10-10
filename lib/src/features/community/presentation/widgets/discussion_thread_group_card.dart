import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_structured_body.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Discussion Thread Group Card (Level 1 Parent + Level 2 Child Replies with Continuous Spine & Anchor Curves)
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
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
              Row(
                children: [
                  if (isAiReply)
                    ClipOval(
                      child: Image(
                        image: AppAssets.images.syllabotAvatar.provider(),
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.syllabotAccent.withAlpha(
                              isDark ? 40 : 25,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.smart_toy_rounded,
                            size: 16,
                            color: colors.syllabotAccent,
                          ),
                        ),
                      ),
                    )
                  else if (parentReply.isAnonymous)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceBorder.withAlpha(40),
                        border: Border.all(
                          color: colors.textSecondary.withAlpha(
                            isDark ? 60 : 35,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility_off_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    )
                  else
                    AppAvatar(
                      customDimension: 28,
                      name: parentReply.authorName,
                      backgroundColor: colors.primary.withAlpha(
                        isDark ? 40 : 25,
                      ),
                      foregroundColor: colors.primary,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                parentReply.isAnonymous
                                    ? parentReply.authorName
                                    : '@${parentReply.authorName}',
                                style: typography.subhead.bold.copyWith(
                                  color: isAiReply
                                      ? colors.syllabotAccent
                                      : (parentReply.isAnonymous
                                            ? colors.textSecondary
                                            : colors.textPrimary),
                                  fontSize: 13.5,
                                  fontStyle: parentReply.isAnonymous
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (parentReply.isAnonymous)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withAlpha(
                                    isDark ? 35 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
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
                                      size: 8.5,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Incognito',
                                      style: typography.caption.medium.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isAiReply)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.syllabotAccent.withAlpha(
                                    isDark ? 35 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AI TUTOR',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.syllabotAccent,
                                    fontSize: 9,
                                  ),
                                ),
                              )
                            else if (isOp)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OP',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 9,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colors.surfacePrimary.withAlpha(180)
                                      : colors.surfaceSecondary,
                                ),
                                child: Text(
                                  'Scholar',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _formatTime(parentReply.createdAt, l10n),
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ShrinkableButton(
                    onTap: () => showForumReplyOptionsMenu(
                      context,
                      parentReply,
                      onEdit: onEditReply,
                      onDelete: onDeleteReply,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Body Text
              CleanFormattedText(
                text: parentReply.content,
                baseStyle: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              if (parentReply.latexContent != null &&
                  parentReply.latexContent!.isNotEmpty) ...[
                const SizedBox(height: 6),
                LatexFormulaBlock(
                  formula: parentReply.latexContent!,
                  backgroundColor: isDark
                      ? colors.surfacePrimary
                      : colors.surfaceSecondary.withAlpha(120),
                  borderColor: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                  textStyle: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 13,
                  ),
                ),
              ],

              // Voice note if attached
              if (parentReply.voiceNoteUrl != null &&
                  parentReply.voiceNoteUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                VoiceNotePlayerWidget(
                  audioUrl: parentReply.voiceNoteUrl!,
                  replyId: parentReply.id,
                  durationSeconds: parentReply.voiceNoteDurationSeconds,
                  transcript: parentReply.voiceNoteTranscript,
                  compact: true,
                  onTranscriptLoaded: (newTranscript) {
                    onTranscriptUpdated?.call(parentReply.id, newTranscript);
                  },
                ),
              ],

              // Media images if attached
              if (parentReply.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...parentReply.mediaUrls.asMap().entries.map(
                  (entry) => ForumReplyAttachmentCard(
                    imageUrl: entry.value,
                    customFileName: extractAttachmentFileName(
                      entry.value,
                      index: entry.key,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Interaction Row (Vote Pill + Reply Button + Verify Solution if Bounty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
              ),
            ],
          ),
        ),

        // SUB-REPLIES SECTION (Only shown if totalChildCount > 0 or children.isNotEmpty)
        if (totalChildCount > 0 || children.isNotEmpty) ...[
          if (!isExpanded) ...[
            // Collapsed Comment / View Replies Trigger
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 8),
              child: Stack(
                children: [
                  // Connecting spine guide leading down
                  Positioned(
                    left: 7,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceBorder.withAlpha(70)
                            : colors.primary.withAlpha(isDark ? 70 : 40),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: ShrinkableButton(
                      onTap: onToggleExpand,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorder.withAlpha(40)
                                : colors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            if (isLoadingChildren) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Loading replies...',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              Text(
                                children.isNotEmpty
                                    ? '@${children.first.authorName}'
                                    : 'Replies ($totalChildCount)',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• View $totalChildCount ${totalChildCount == 1 ? 'reply' : 'replies'}',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Expanded Sub-replies List with continuous vertical guide line
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 8),
              child: Stack(
                children: [
                  // Continuous Connecting Spine Line (vertical guide rod)
                  Positioned(
                    left: 7,
                    top: 0,
                    bottom: 12,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceBorder.withAlpha(70)
                            : colors.primary.withAlpha(isDark ? 70 : 40),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // List of Child Replies
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      children: [
                        ...children.map((child) {
                          return Level2ChildReplyCard(
                            childReply: child,
                            opAuthorName: opAuthorName,
                            isHighlighted: child.id == highlightReplyId,
                            onVote: (direction) =>
                                onChildVote(child, direction),
                            onReplyTap: () => onChildReplyTap(child),
                            onEdit: onEditChildReply != null
                                ? () => onEditChildReply!(child)
                                : null,
                            onDelete: onDeleteChildReply != null
                                ? () => onDeleteChildReply!(child)
                                : null,
                            onTranscriptUpdated: onTranscriptUpdated,
                          );
                        }),

                        // Sub-replies Pagination Trigger
                        if (hasMoreChildren) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: ShrinkableButton(
                              onTap: isLoadingChildren
                                  ? null
                                  : onLoadMoreChildren,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfacePrimary,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.primary.withAlpha(
                                      isDark ? 40 : 25,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isLoadingChildren)
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                colors.primary,
                                              ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 14,
                                        color: colors.primary,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isLoadingChildren
                                          ? 'Loading more...'
                                          : 'Load more replies',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Collapse whole sub-thread
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ShrinkableButton(
                            onTap: onToggleExpand,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.expand_less_rounded,
                                    size: 14,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Collapse replies',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Displays an author action menu (Edit, Delete) or Report menu for any forum reply.
void showForumReplyOptionsMenu(
  BuildContext context,
  ForumReplyEntity reply, {
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  unawaited(HapticFeedback.lightImpact());
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;
  final userStorage = locator<UserStorageService>();
  final currentUserId = userStorage.getUserId();
  final currentUserName = userStorage.getUserDisplayName() ?? '';
  final isReplyAuthor =
      (currentUserId != null && currentUserId == reply.authorId) ||
      (!reply.isAnonymous &&
          currentUserName.isNotEmpty &&
          currentUserName.toLowerCase() == reply.authorName.toLowerCase());

  unawaited(
    AppAdaptiveSheet.showActionMenu<void>(
      context: context,
      maxWidth: 420,
      builder: (sheetCtx) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetCtx);
        return SafeArea(
          child: Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.dialog),
                    border: Border.all(
                      color: colors.surfaceBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDesktop)
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (isReplyAuthor) ...[
                  ListTile(
                    leading: Icon(
                      Icons.edit_outlined,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Edit Reply',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      onEdit?.call();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Delete Reply',
                      style: typography.body.medium.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      onDelete?.call();
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: colors.error,
                    ),
                    title: Text(
                      'Report Reply',
                      style: typography.body.medium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      unawaited(
                        ReportContentModalSheet.show(
                          context,
                          contentType: 'forum_reply',
                          contentId: reply.id,
                          contentTitle: reply.content,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Level 2 Child Reply Node with Horizontal Anchor Indicator and Collapsible state
class Level2ChildReplyCard extends HookWidget {
  const Level2ChildReplyCard({
    required this.childReply,
    required this.opAuthorName,
    required this.onVote,
    required this.onReplyTap,
    super.key,
    this.isHighlighted = false,
    this.onEdit,
    this.onDelete,
    this.onTranscriptUpdated,
  });

  final ForumReplyEntity childReply;
  final String opAuthorName;
  final void Function(int direction) onVote;
  final VoidCallback onReplyTap;
  final bool isHighlighted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(String replyId, String newTranscript)?
  onTranscriptUpdated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isCollapsed = useState<bool>(false);
    final isUpvoted = childReply.userVote == 1;
    final isDownvoted = childReply.userVote == -1;

    final isOp =
        childReply.authorName.toLowerCase() == opAuthorName.toLowerCase();
    final isAiReply =
        childReply.authorName.toLowerCase().contains('syllabot') ||
        childReply.content.contains('🤖');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Child Anchor curve / horizontal indicator connecting to vertical spine
          Positioned(
            left: -16,
            top: 18,
            child: Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceBorder.withAlpha(80)
                    : colors.surfaceBorder.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Main Child Card / Collapsed banner
          if (isCollapsed.value)
            ShrinkableButton(
              onTap: () => isCollapsed.value = false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (isDark
                      ? colors.surfaceSecondary
                      : colors.surfaceSecondary.withAlpha(120)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      childReply.isAnonymous
                          ? childReply.authorName
                          : '@${childReply.authorName}',
                      style: typography.caption.bold.copyWith(
                        color: childReply.isAnonymous
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontSize: 12,
                        fontStyle: childReply.isAnonymous
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• Collapsed comment',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(180)
                    : colors.surfaceSecondary.withAlpha(90),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isHighlighted
                      ? colors.primary
                      : colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                  width: isHighlighted ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isHighlighted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 11,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Highlighted Reply',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Author Info & Collapse Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (childReply.isAnonymous)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfaceBorder.withAlpha(40),
                                  border: Border.all(
                                    color: colors.textSecondary.withAlpha(
                                      isDark ? 60 : 35,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_off_rounded,
                                  size: 12,
                                  color: colors.textSecondary,
                                ),
                              )
                            else
                              AppAvatar(
                                customDimension: 22,
                                name: childReply.authorName,
                                backgroundColor: colors.primary.withAlpha(
                                  isDark ? 40 : 25,
                                ),
                                foregroundColor: colors.primary,
                              ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                childReply.isAnonymous
                                    ? childReply.authorName
                                    : '@${childReply.authorName}',
                                style: typography.caption.bold.copyWith(
                                  color: isAiReply
                                      ? colors.syllabotAccent
                                      : (childReply.isAnonymous
                                            ? colors.textSecondary
                                            : colors.textPrimary),
                                  fontSize: 12.5,
                                  fontStyle: childReply.isAnonymous
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (childReply.isAnonymous) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0.8,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withAlpha(
                                    isDark ? 35 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: colors.textSecondary.withAlpha(
                                      isDark ? 60 : 35,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 7.5,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      'Incognito',
                                      style: typography.caption.medium.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 7.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isOp) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OP',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(childReply.createdAt, l10n),
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ShrinkableButton(
                        onTap: () => showForumReplyOptionsMenu(
                          context,
                          childReply,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ShrinkableButton(
                        onTap: () => isCollapsed.value = true,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.unfold_less_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Body Text
                  CleanFormattedText(
                    text: childReply.content,
                    baseStyle: typography.footnote.regular.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  if (childReply.latexContent != null &&
                      childReply.latexContent!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    LatexFormulaBlock(
                      formula: childReply.latexContent!,
                      backgroundColor: isDark
                          ? colors.surfacePrimary
                          : colors.surfaceSecondary.withAlpha(120),
                      borderColor: colors.surfaceBorder.withAlpha(
                        isDark ? 30 : 20,
                      ),
                      textStyle: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  // Voice note if attached
                  if (childReply.voiceNoteUrl != null &&
                      childReply.voiceNoteUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    VoiceNotePlayerWidget(
                      audioUrl: childReply.voiceNoteUrl!,
                      replyId: childReply.id,
                      durationSeconds: childReply.voiceNoteDurationSeconds,
                      transcript: childReply.voiceNoteTranscript,
                      compact: true,
                      onTranscriptLoaded: (newTranscript) {
                        onTranscriptUpdated?.call(childReply.id, newTranscript);
                      },
                    ),
                  ],

                  // Media images if attached
                  if (childReply.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...childReply.mediaUrls.asMap().entries.map(
                      (entry) => ForumReplyAttachmentCard(
                        imageUrl: entry.value,
                        customFileName: extractAttachmentFileName(
                          entry.value,
                          index: entry.key,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Interaction Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfacePrimary.withAlpha(140)
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShrinkableButton(
                              onTap: () => onVote(1),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 14,
                                  color: isUpvoted
                                      ? colors.recallEasy
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                childReply.netVotes > 0
                                    ? '+${childReply.netVotes}'
                                    : '${childReply.netVotes}',
                                style: typography.caption.bold.copyWith(
                                  color: isUpvoted
                                      ? colors.recallEasy
                                      : (isDownvoted
                                            ? colors.error
                                            : colors.recallEasy),
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            ShrinkableButton(
                              onTap: () => onVote(-1),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
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
                      ShrinkableButton(
                        onTap: onReplyTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 13,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Reply',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
