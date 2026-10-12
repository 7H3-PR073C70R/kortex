import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/edit_post_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Shows an action menu sheet with contextual post operations (share, copy link,
/// report, and edit/delete if the current user is the author).
Future<void> showPostCardOptionsMenu(
  BuildContext context, {
  required ForumPostEntity post,
  LinkSharingService? linkSharingService,
  UserStorageService? userStorageService,
  CommunityRepository? communityRepository,
  CommunityHubBloc? communityHubBloc,
  VoidCallback? onEditRequested,
}) {
  unawaited(HapticFeedback.lightImpact());
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;
  final l10n = context.l10n;

  final resolvedLinkSharing =
      linkSharingService ??
      (locator.isRegistered<LinkSharingService>()
          ? locator<LinkSharingService>()
          : null);
  final resolvedUserStorage =
      userStorageService ??
      (locator.isRegistered<UserStorageService>()
          ? locator<UserStorageService>()
          : null);
  final resolvedHubBloc =
      communityHubBloc ??
      (locator.isRegistered<CommunityHubBloc>()
          ? locator<CommunityHubBloc>()
          : null);

  return AppAdaptiveSheet.showActionMenu<void>(
    context: context,
    maxWidth: 420,
    builder: (ctx) {
      final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
      return SafeArea(
        top: false,
        child: Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDesktop)
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withAlpha(80),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Share Thread',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
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
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.link_rounded,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Copy Link',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (resolvedLinkSharing != null) {
                        final result = await resolvedLinkSharing.shareForumPost(
                          postId: post.id,
                          title: post.title,
                          authorName: post.authorName,
                          subjectTrack: post.track,
                        );
                        final copied = await resolvedLinkSharing
                            .copyLinkToClipboard(result.linkUri);
                        if (copied && context.mounted) {
                          context.showSnackBar(
                            message: 'Post link copied to clipboard',
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: colors.error,
                    ),
                    title: Text(
                      'Report Content',
                      style: typography.body.medium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      unawaited(
                        ReportContentModalSheet.show(
                          context,
                          contentType: 'forum_post',
                          contentId: post.id,
                          postId: post.id,
                          contentTitle: post.title,
                        ),
                      );
                    },
                  ),
                  if (() {
                    final currentUserId = resolvedUserStorage?.getUserId();
                    final currentUserName =
                        resolvedUserStorage?.getUserDisplayName();
                    return (currentUserId != null &&
                            currentUserId == post.authorId) ||
                        (currentUserName != null &&
                            currentUserName == post.authorName);
                  }()) ...[
                    ListTile(
                      leading: Icon(
                        Icons.edit_outlined,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        'Edit Discussion',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (onEditRequested != null) {
                          onEditRequested();
                        } else {
                          unawaited(
                            showEditPostModalSheet(
                              context,
                              post: post,
                              communityRepository: communityRepository,
                              communityHubBloc: communityHubBloc,
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.error,
                      ),
                      title: Text(
                        'Delete Discussion',
                        style: typography.body.medium.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: isDark
                                ? colors.surfaceSecondary
                                : colors.surfacePrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              'Delete Discussion?',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to permanently delete this discussion thread and all its replies?',
                              style: typography.body.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogCtx).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: typography.body.medium.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.error,
                                  foregroundColor: colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogCtx).pop(true),
                                child: Text(l10n.commonDelete),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          resolvedHubBloc?.add(
                            DeleteForumPostEvent(post.id),
                          );
                          if (context.mounted) {
                            context.showSnackBar(
                              message: 'Discussion deleted successfully',
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
