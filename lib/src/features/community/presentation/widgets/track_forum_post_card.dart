import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/edit_post_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_actions_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_author_row.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_content_preview.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_header.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_media_section.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_options_menu.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_tags_row.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Primary thread card widget displayed in the subject track forum discussion feeds.
class TrackForumPostCard extends HookWidget {
  const TrackForumPostCard({
    required this.post,
    required this.onTap,
    this.onUpvoteTap,
    this.onDownvoteTap,
    this.isSelected = false,
    this.linkSharingService,
    this.userStorageService,
    this.communityRepository,
    this.communityHubBloc,
    super.key,
  });

  final ForumPostEntity post;
  final VoidCallback onTap;
  final VoidCallback? onUpvoteTap;
  final VoidCallback? onDownvoteTap;
  final bool isSelected;
  final LinkSharingService? linkSharingService;
  final UserStorageService? userStorageService;
  final CommunityRepository? communityRepository;
  final CommunityHubBloc? communityHubBloc;

  void _showPostOptionsMenu(BuildContext context) {
    unawaited(
      showPostCardOptionsMenu(
        context,
        post: post,
        linkSharingService: linkSharingService,
        userStorageService: userStorageService,
        communityRepository: communityRepository,
        communityHubBloc: communityHubBloc,
        onEditRequested: () => showEditPostModalSheet(
          context,
          post: post,
          communityRepository: communityRepository,
          communityHubBloc: communityHubBloc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final semanticsLabel =
        'Forum Post: ${post.title}, Track: ${post.track}, '
        'By ${post.authorName}, Score: ${post.netVotes}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ShrinkableButton(
        onTap: onTap,
        shrinkScale: 0.985,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) => AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? colors.primary.withAlpha(25)
                      : colors.primary.withAlpha(12))
                  : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : post.isVerifiedSolution
                        ? colors.success.withAlpha(
                            isDark
                                ? (isHovered ? 120 : 60)
                                : (isHovered ? 80 : 40),
                          )
                        : isHovered
                            ? colors.primary.withAlpha(isDark ? 80 : 60)
                            : (isDark
                                ? colors.surfaceBorder.withAlpha(30)
                                : colors.surfaceBorder.withAlpha(15)),
                width: isSelected || isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? colors.primary.withAlpha(isDark ? 40 : 20)
                      : colors.black.withAlpha(
                          isDark ? (isHovered ? 50 : 25) : (isHovered ? 16 : 6),
                        ),
                  blurRadius: isSelected || isHovered ? 14 : 8,
                  offset: Offset(0, isSelected || isHovered ? 4 : 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel & Options Header: [Dot + c/Track] ... [Badges] [more_horiz]
                  PostCardHeader(
                    post: post,
                    onOptionsTap: () => _showPostOptionsMenu(context),
                  ),
                  const SizedBox(height: 10),

                  // Author Row: [Avatar with online ring] [Name] [PRO/MOD badge] • [Time]
                  PostCardAuthorRow(post: post),
                  const SizedBox(height: 12),

                  // Post Title, Snippet & Rich Preview
                  PostCardContentPreview(post: post),

                  // Voice note and Image Attachments
                  PostCardMediaSection(post: post),
                  const SizedBox(height: 10),

                  // Tags Row
                  PostCardTagsRow(post: post),
                  const SizedBox(height: 12),

                  // Actions Bar: [Vote Capsule] [Reply Pill] ... [Share] [Bookmark]
                  PostCardActionsBar(
                    post: post,
                    onUpvoteTap: onUpvoteTap,
                    onDownvoteTap: onDownvoteTap,
                    linkSharingService: linkSharingService,
                    communityRepository: communityRepository,
                    communityHubBloc: communityHubBloc,
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
