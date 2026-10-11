import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/discussion_thread_group_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Available sorting modes for forum replies in the thread detail screen.
enum ForumSortFilter {
  topVoted('Top voted', Icons.swap_vert_rounded),
  mostRecent('Latest', Icons.schedule_rounded),
  aiFirst('AI First', Icons.auto_awesome_rounded),
  unanswered('Unanswered', Icons.help_outline_rounded);

  const ForumSortFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Sliver displaying the replies header with count indicator and sorting popup filter.
class ForumThreadRepliesHeaderSliver extends StatelessWidget {
  const ForumThreadRepliesHeaderSliver({
    required this.repliesCount,
    required this.sortFilter,
    required this.onSortFilterSelected,
    super.key,
  });

  final int repliesCount;
  final ForumSortFilter sortFilter;
  final ValueChanged<ForumSortFilter> onSortFilterSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(
          children: [
            Text(
              'Replies',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary
                    : colors.surfaceTertiary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$repliesCount',
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
            const Spacer(),
            PopupMenuButton<ForumSortFilter>(
              initialValue: sortFilter,
              tooltip: l10n.tooltipSortReplies,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                ),
              ),
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              onSelected: (filter) {
                unawaited(HapticFeedback.selectionClick());
                onSortFilterSelected(filter);
              },
              itemBuilder: (context) => ForumSortFilter.values.map((f) {
                final isSelected = f == sortFilter;
                return PopupMenuItem<ForumSortFilter>(
                  value: f,
                  child: Row(
                    children: [
                      Icon(
                        f.icon,
                        size: 16,
                        color: isSelected
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        f.label,
                        style: typography.footnote.medium.copyWith(
                          color: isSelected
                              ? colors.primary
                              : colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(160)
                      : colors.surfaceSecondary.withAlpha(110),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sortFilter.icon,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sortFilter.label,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver displaying replies in a threaded tree, or an empty/loading state.
class ForumThreadRepliesListSliver extends StatelessWidget {
  const ForumThreadRepliesListSliver({
    required this.allReplies,
    required this.sortFilter,
    required this.isInitialLoading,
    required this.isGeneratingAiHint,
    required this.currentUserId,
    required this.isAuthor,
    required this.isQuestion,
    required this.opAuthorName,
    required this.highlightReplyId,
    required this.expandedParentReplyIds,
    required this.loadingParentReplyIds,
    required this.hasMoreSubRepliesMap,
    required this.onToggleExpand,
    required this.onLoadMoreChildren,
    required this.onVoteReply,
    required this.onReplyTap,
    required this.onSaveFlashcard,
    required this.onEditReply,
    required this.onDeleteReply,
    required this.onTranscriptUpdated,
    required this.onVerifySolution,
    required this.onGenerateAiHint,
    super.key,
  });

  final List<ForumReplyEntity> allReplies;
  final ForumSortFilter sortFilter;
  final bool isInitialLoading;
  final bool isGeneratingAiHint;
  final String? currentUserId;
  final bool isAuthor;
  final bool isQuestion;
  final String opAuthorName;
  final String? highlightReplyId;
  final Set<String> expandedParentReplyIds;
  final Set<String> loadingParentReplyIds;
  final Map<String, bool> hasMoreSubRepliesMap;
  final void Function(String parentReplyId) onToggleExpand;
  final void Function(String parentReplyId) onLoadMoreChildren;
  final void Function(ForumReplyEntity targetReply, int direction) onVoteReply;
  final void Function(ForumReplyEntity targetReply) onReplyTap;
  final void Function(ForumReplyEntity targetReply) onSaveFlashcard;
  final void Function(ForumReplyEntity targetReply) onEditReply;
  final void Function(ForumReplyEntity targetReply) onDeleteReply;
  final void Function(String targetReplyId, String newTranscript)
      onTranscriptUpdated;
  final void Function(ForumReplyEntity targetReply) onVerifySolution;
  final VoidCallback onGenerateAiHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    // Filter & sort top-level replies
    final topLevelReplies = (allReplies
        .where(
          (r) => r.parentReplyId == null || r.parentReplyId!.isEmpty,
        )
        .toList())
      ..sort((a, b) {
        if (a.isVerifiedSolution != b.isVerifiedSolution) {
          return a.isVerifiedSolution ? -1 : 1;
        }

        switch (sortFilter) {
          case ForumSortFilter.mostRecent:
            return b.createdAt.compareTo(a.createdAt);
          case ForumSortFilter.topVoted:
            final voteComp = b.netVotes.compareTo(a.netVotes);
            if (voteComp != 0) return voteComp;
            return b.createdAt.compareTo(a.createdAt);
          case ForumSortFilter.aiFirst:
            final aIsAi = a.authorName.toLowerCase().contains('syllabot') ||
                a.content.contains('🤖');
            final bIsAi = b.authorName.toLowerCase().contains('syllabot') ||
                b.content.contains('🤖');
            if (aIsAi != bIsAi) {
              return aIsAi ? -1 : 1;
            }
            return b.netVotes.compareTo(a.netVotes);
          case ForumSortFilter.unanswered:
            final aHasChildren =
                allReplies.any((r) => r.parentReplyId == a.id);
            final bHasChildren =
                allReplies.any((r) => r.parentReplyId == b.id);
            if (aHasChildren != bHasChildren) {
              return aHasChildren ? 1 : -1;
            }
            return b.createdAt.compareTo(a.createdAt);
        }
      });

    // Group nested replies recursively by root top-level parent ID
    final replyById = {for (final r in allReplies) r.id: r};
    String getRootParentId(ForumReplyEntity r) {
      var current = r;
      final visited = <String>{current.id};
      while (current.parentReplyId != null &&
          current.parentReplyId!.isNotEmpty &&
          replyById.containsKey(current.parentReplyId)) {
        final parent = replyById[current.parentReplyId!]!;
        if (visited.contains(parent.id)) break;
        visited.add(parent.id);
        current = parent;
      }
      return current.id;
    }

    final nestedRepliesMap = <String, List<ForumReplyEntity>>{};
    for (final reply in allReplies) {
      if (reply.parentReplyId != null && reply.parentReplyId!.isNotEmpty) {
        final rootId = getRootParentId(reply);
        nestedRepliesMap.putIfAbsent(rootId, () => []).add(reply);
      }
    }
    for (final list in nestedRepliesMap.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final hasAiHintInEmpty = allReplies.any(
      (r) =>
          r.authorName.toLowerCase().contains('syllabot') ||
          r.content.contains('Syllabot') ||
          r.content.contains('🤖') ||
          r.content.contains('Socratic Hint'),
    );

    if (isInitialLoading && topLevelReplies.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading replies...',
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (topLevelReplies.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withAlpha(isDark ? 25 : 15),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 36,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noRepliesYet,
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to share an answer or solution.',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (!hasAiHintInEmpty) ...[
                const SizedBox(height: 18),
                ShrinkableButton(
                  onTap: isGeneratingAiHint ? null : onGenerateAiHint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.snappy,
                      switchInCurve: AppMotion.easeOutCubic,
                      child: Row(
                        key: ValueKey(isGeneratingAiHint),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isGeneratingAiHint)
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isGeneratingAiHint
                                ? 'Consulting Syllabot...'
                                : 'Ask Syllabot for Socratic Hint 🤖',
                            style: typography.caption.bold.copyWith(
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final reply = topLevelReplies[index];
          final children = nestedRepliesMap[reply.id] ?? const [];
          final hasVerifiedSolution = allReplies.any(
            (r) => r.isVerifiedSolution,
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DiscussionThreadGroupCard(
              parentReply: reply,
              children: children,
              highlightReplyId: highlightReplyId,
              opAuthorName: opAuthorName,
              isQuestion: isQuestion,
              isAuthor: isAuthor,
              hasVerifiedSolution: hasVerifiedSolution,
              isExpanded: expandedParentReplyIds.contains(reply.id),
              isLoadingChildren: loadingParentReplyIds.contains(reply.id),
              hasMoreChildren: hasMoreSubRepliesMap[reply.id] ?? false,
              onToggleExpand: () => onToggleExpand(reply.id),
              onLoadMoreChildren: () => onLoadMoreChildren(reply.id),
              onVote: (direction) => onVoteReply(reply, direction),
              onChildVote: onVoteReply,
              onReplyTap: () => onReplyTap(reply),
              onChildReplyTap: onReplyTap,
              onSaveFlashcard: onSaveFlashcard,
              onEditReply: () => onEditReply(reply),
              onDeleteReply: () => onDeleteReply(reply),
              onEditChildReply: onEditReply,
              onDeleteChildReply: onDeleteReply,
              onTranscriptUpdated: onTranscriptUpdated,
              onVerifySolution: () => onVerifySolution(reply),
            ),
          )
              .animate(delay: (index.clamp(0, 5) * 80).ms)
              .fadeIn(
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.05,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              );
        },
        childCount: topLevelReplies.length,
      ),
    );
  }
}

/// Sliver displaying the pagination trigger button for loading more top-level replies.
class ForumThreadPaginationSliver extends StatelessWidget {
  const ForumThreadPaginationSliver({
    required this.isLoadingMore,
    required this.onLoadMore,
    super.key,
  });

  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Center(
          child: ShrinkableButton(
            onTap: isLoadingMore ? null : onLoadMore,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? colors.surfaceBorder.withAlpha(40)
                      : colors.surfaceBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 20 : 6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoadingMore) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading more discussions...',
                      style: typography.footnote.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.expand_circle_down_outlined,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Load more discussions',
                      style: typography.footnote.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
