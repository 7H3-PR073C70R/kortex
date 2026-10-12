import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom actions bar for TrackForumPostCard assembling the vote capsule,
/// reply count pill, share button, and bookmark toggle.
class PostCardActionsBar extends StatelessWidget {
  const PostCardActionsBar({
    required this.post,
    this.onUpvoteTap,
    this.onDownvoteTap,
    this.linkSharingService,
    this.communityRepository,
    this.communityHubBloc,
    super.key,
  });

  final ForumPostEntity post;
  final VoidCallback? onUpvoteTap;
  final VoidCallback? onDownvoteTap;
  final LinkSharingService? linkSharingService;
  final CommunityRepository? communityRepository;
  final CommunityHubBloc? communityHubBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isUpvoted = post.userVote == 1;
    final isDownvoted = post.userVote == -1;

    final resolvedLinkSharing =
        linkSharingService ??
        (locator.isRegistered<LinkSharingService>()
            ? locator<LinkSharingService>()
            : null);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left actions: Votes & Replies
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Upvote / Downvote Capsule
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: (isUpvoted || isDownvoted)
                      ? (isUpvoted
                            ? colors.primary.withAlpha(isDark ? 35 : 20)
                            : colors.error.withAlpha(isDark ? 35 : 20))
                      : (isDark
                            ? colors.surfacePrimary.withAlpha(180)
                            : colors.surfaceSecondary.withAlpha(120)),
                  borderRadius: AppRadius.radiusBadge,
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
                        child: AnimatedSwitcher(
                          duration: AppMotion.snappy,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: AppMotion.easeOutCubic,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: anim,
                              child: child,
                            ),
                          ),
                          child: Icon(
                            isUpvoted
                                ? Icons.arrow_circle_up_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            key: ValueKey<bool>(isUpvoted),
                            size: 18,
                            color: isUpvoted
                                ? colors.primary
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedDefaultTextStyle(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        style: typography.caption.bold.copyWith(
                          color: isUpvoted
                              ? colors.primary
                              : isDownvoted
                              ? colors.error
                              : colors.textPrimary,
                          fontSize: 12,
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.snappy,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: Tween<double>(begin: 0.85, end: 1).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: AppMotion.easeOutCubic,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: anim,
                              child: child,
                            ),
                          ),
                          child: Text(
                            '${post.netVotes}',
                            key: ValueKey<int>(post.netVotes),
                          ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.snappy,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: AppMotion.easeOutCubic,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: anim,
                              child: child,
                            ),
                          ),
                          child: Icon(
                            isDownvoted
                                ? Icons.arrow_circle_down_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            key: ValueKey<bool>(isDownvoted),
                            size: 18,
                            color: isDownvoted
                                ? colors.error
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Reply Pill
              Flexible(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary.withAlpha(180)
                        : colors.surfaceSecondary.withAlpha(120),
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          post.topLevelRepliesCount == 1
                              ? '1 reply'
                              : '${post.topLevelRepliesCount} replies',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right actions: Share & Bookmark
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlatformHoverBuilder(
              builder: (context, isShareHovered, child) => AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isShareHovered
                      ? colors.primary.withAlpha(isDark ? 40 : 25)
                      : colors.transparent,
                  borderRadius: AppRadius.radiusMicro,
                ),
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    if (resolvedLinkSharing != null) {
                      unawaited(
                        resolvedLinkSharing.shareForumPost(
                          postId: post.id,
                          title: post.title,
                          authorName: post.authorName,
                          subjectTrack: post.track,
                        ),
                      );
                    }
                  },
                  child: Center(
                    child: Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: isShareHovered
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Builder(
              builder: (context) {
                final isBookmarked = context.select<CommunityHubBloc?, bool>(
                  (bloc) =>
                      bloc?.state.bookmarkedPostIds.contains(post.id) ?? false,
                );
                return PlatformHoverBuilder(
                  builder: (context, isBmHovered, child) => AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isBmHovered
                          ? colors.primary.withAlpha(isDark ? 40 : 25)
                          : colors.transparent,
                      borderRadius: AppRadius.radiusMicro,
                    ),
                    child: ShrinkableButton(
                      onTap: () async {
                        unawaited(HapticFeedback.lightImpact());
                        final hubBloc =
                            communityHubBloc ??
                            context.read<CommunityHubBloc?>();
                        if (hubBloc != null) {
                          hubBloc.add(
                            ToggleBookmarkForumPostEvent(post.id),
                          );
                        } else {
                          final repo =
                              communityRepository ??
                              (locator.isRegistered<CommunityRepository>()
                                  ? locator<CommunityRepository>()
                                  : null);
                          await repo?.toggleBookmarkForumPost(post.id);
                        }
                        final newBookmarked = !isBookmarked;
                        if (context.mounted) {
                          context.showSnackBar(
                            message: newBookmarked
                                ? 'Thread saved to bookmarks'
                                : 'Thread removed from bookmarks',
                          );
                        }
                      },
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: AppMotion.snappy,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: Tween<double>(begin: 0.75, end: 1).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: AppMotion.easeOutCubic,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: anim,
                              child: child,
                            ),
                          ),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            key: ValueKey<bool>(isBookmarked),
                            size: 19,
                            color: isBookmarked
                                ? colors.primary
                                : (isBmHovered
                                      ? colors.primary
                                      : colors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
