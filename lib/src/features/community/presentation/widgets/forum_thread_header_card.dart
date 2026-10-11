import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_post_vote_pill.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_structured_body.dart';
import 'package:kortex/src/features/community/presentation/widgets/subject_master_badge.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Card displaying the original forum post at the top of the thread detail screen.
///
/// Encapsulates channel badges, author credentials, structured content body,
/// LaTeX equations, voice recordings, media attachments, tags, voting, and action controls.
class ForumThreadHeaderCard extends StatelessWidget {
  const ForumThreadHeaderCard({
    required this.post,
    required this.isBookmarked,
    required this.repliesCount,
    required this.onVote,
    required this.onBookmark,
    required this.onShare,
    required this.onShowOptionsMenu,
    required this.onTranscriptLoaded,
    required this.onGenerateDeck,
    super.key,
  });

  final ForumPostEntity post;
  final bool isBookmarked;
  final int repliesCount;
  final void Function(int direction) onVote;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onShowOptionsMenu;
  final void Function(String newTranscript) onTranscriptLoaded;
  final VoidCallback onGenerateDeck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel Pill & Meta Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfacePrimary.withAlpha(180)
                      : colors.primary.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.widgets_outlined,
                      size: 12,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'c/${post.track}',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.textSecondary.withAlpha(120),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Posted ${_formatTime(post.createdAt, l10n)}',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              const Spacer(),
              ShrinkableButton(
                onTap: onShowOptionsMenu,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Author Profile Row
          Row(
            children: [
              if (post.isAnonymous)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfaceBorder.withAlpha(40),
                    border: Border.all(
                      color: colors.textSecondary.withAlpha(isDark ? 60 : 35),
                    ),
                  ),
                  child: Icon(
                    Icons.visibility_off_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                )
              else
                AppAvatar(
                  customDimension: 40,
                  name: post.authorName,
                  backgroundColor:
                      colors.primary.withAlpha(isDark ? 50 : 35),
                  foregroundColor: colors.primary,
                  badgeColor: colors.success,
                  badgeBorderColor: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
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
                            post.isAnonymous
                                ? post.authorName
                                : '@${post.authorName}',
                            style: typography.subhead.bold.copyWith(
                              color: post.isAnonymous
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                              fontSize: 14.5,
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
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withAlpha(
                                isDark ? 40 : 25,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colors.textSecondary.withAlpha(
                                  isDark ? 70 : 40,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 10,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Incognito OP',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
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
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SubjectMasterBadge(
                            track: post.track,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.isAnonymous
                          ? 'Incognito Mode • Identities are protected'
                          : (post.syllabusTag.isNotEmpty
                              ? 'Staff Level Scholar • ${post.syllabusTag}'
                              : 'Staff Level Scholar'),
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            _cleanTitle(post.title, post.syllabusTag, post.track),
            style: typography.title2.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 18,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Structured Content Body Card
          ForumThreadStructuredBody(post: post),

          // LaTeX Formula block
          if (post.latexContent != null &&
              post.latexContent!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary
                    : colors.surfaceSecondary.withAlpha(140),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withAlpha(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.formulaEquation,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LatexFormulaBlock(
                    formula: post.latexContent!,
                    backgroundColor: Colors.transparent,
                    borderColor: colors.primary.withAlpha(
                      isDark ? 50 : 30,
                    ),
                    textStyle: typography.body.bold.copyWith(
                      color: colors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Voice note player preview if present
          if (post.voiceNoteUrl != null &&
              post.voiceNoteUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            VoiceNotePlayerWidget(
              audioUrl: post.voiceNoteUrl!,
              postId: post.id,
              durationSeconds: post.voiceNoteDurationSeconds,
              transcript: post.voiceNoteTranscript,
              onTranscriptLoaded: onTranscriptLoaded,
            ),
          ],

          // Media Images preview if present
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            ForumPostMediaPreview(
              mediaUrls: post.mediaUrls,
              heroHeight: 165,
            ),
          ],

          // Semantic Tags Wrap
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.tags.map((tag) {
                final displayTag =
                    tag.startsWith('#') ? tag : '#$tag';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary.withAlpha(160)
                        : colors.primary.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayTag,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // OP Interactive Action Bar (Vote Group Pill, Replies Count, Bookmark, Deck, Share)
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ForumPostVotePill(
                          netVotes: post.netVotes,
                          userVote: post.userVote,
                          onUpvote: () => onVote(1),
                          onDownvote: () => onVote(-1),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$repliesCount',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Bookmark Button
              ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onBookmark();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBookmarked
                        ? colors.primary.withAlpha(isDark ? 35 : 20)
                        : colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 19,
                    color: isBookmarked
                        ? colors.primary
                        : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Generate Deck Button
              ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onGenerateDeck();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Share Button
              ShrinkableButton(
                onTap: onShare,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.share_outlined,
                    size: 19,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _cleanTitle(
    String title,
    String syllabusTag,
    String track,
  ) {
    var cleaned = title.replaceAll(RegExp(r'\*\*|__'), '').trim();
    if (cleaned.toLowerCase().startsWith('question discussion:')) {
      cleaned = cleaned.substring('question discussion:'.length).trim();
    } else if (cleaned.toLowerCase().startsWith('question:')) {
      cleaned = cleaned.substring('question:'.length).trim();
    }
    return cleaned.isEmpty ? '$syllabusTag ($track) Discussion' : cleaned;
  }
}
