import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_structured_body.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_options_menu.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Level 2 Child Reply Node with Horizontal Anchor Indicator and Collapsible state.
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
    this.userStorage,
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
  final UserStorageService? userStorage;

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
                          userStorage: userStorage,
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
