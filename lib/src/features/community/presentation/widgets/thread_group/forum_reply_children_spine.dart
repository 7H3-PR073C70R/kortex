import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/level2_child_reply_card.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Renders the connecting continuous spine guide rod and list of nested Level 2 replies.
///
/// Supports collapsed reply count badge, lazy pagination trigger, and full thread collapse.
class ForumReplyChildrenSpine extends StatelessWidget {
  const ForumReplyChildrenSpine({
    required this.totalChildCount,
    required this.children,
    required this.isExpanded,
    required this.isLoadingChildren,
    required this.hasMoreChildren,
    required this.opAuthorName,
    required this.onToggleExpand,
    required this.onLoadMoreChildren,
    required this.onChildVote,
    required this.onChildReplyTap,
    super.key,
    this.highlightReplyId,
    this.onEditChildReply,
    this.onDeleteChildReply,
    this.onTranscriptUpdated,
    this.userStorage,
  });

  final int totalChildCount;
  final List<ForumReplyEntity> children;
  final bool isExpanded;
  final bool isLoadingChildren;
  final bool hasMoreChildren;
  final String opAuthorName;
  final String? highlightReplyId;
  final VoidCallback onToggleExpand;
  final VoidCallback onLoadMoreChildren;
  final void Function(ForumReplyEntity child, int direction) onChildVote;
  final void Function(ForumReplyEntity child) onChildReplyTap;
  final void Function(ForumReplyEntity child)? onEditChildReply;
  final void Function(ForumReplyEntity child)? onDeleteChildReply;
  final void Function(String replyId, String newTranscript)?
  onTranscriptUpdated;
  final UserStorageService? userStorage;

  @override
  Widget build(BuildContext context) {
    if (totalChildCount == 0 && children.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (!isExpanded) {
      // Collapsed Comment / View Replies Trigger
      return Padding(
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
      );
    }

    // Expanded Sub-replies List with continuous vertical guide line
    return Padding(
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
                    onVote: (direction) => onChildVote(child, direction),
                    onReplyTap: () => onChildReplyTap(child),
                    onEdit: onEditChildReply != null
                        ? () => onEditChildReply!(child)
                        : null,
                    onDelete: onDeleteChildReply != null
                        ? () => onDeleteChildReply!(child)
                        : null,
                    onTranscriptUpdated: onTranscriptUpdated,
                    userStorage: userStorage,
                  );
                }),

                // Sub-replies Pagination Trigger
                if (hasMoreChildren) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: ShrinkableButton(
                      onTap: isLoadingChildren ? null : onLoadMoreChildren,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
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
    );
  }
}
