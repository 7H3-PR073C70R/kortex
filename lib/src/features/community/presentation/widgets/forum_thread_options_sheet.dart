import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Bottom action sheet offering contextual operations on a forum thread
/// (bookmarking, notifications, sharing, live study room launch, editing, deleting, or reporting).
class ForumThreadOptionsSheet {
  const ForumThreadOptionsSheet._();

  static Future<void> show(
    BuildContext context, {
    required ForumPostEntity post,
    required bool isBookmarked,
    required bool isSubscribed,
    required bool isAuthor,
    required VoidCallback onToggleBookmark,
    required VoidCallback onToggleSubscription,
    required VoidCallback onShare,
    required Future<void> Function() onCopyLink,
    required VoidCallback onEditPost,
    required VoidCallback onDeletePost,
    required VoidCallback onReport,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    await AppAdaptiveSheet.showActionMenu<void>(
      context: context,
      maxWidth: 420,
      builder: (ctx) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
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
                      color: colors.textSecondary.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ListTile(
                  leading: Icon(
                    isBookmarked
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                    color: colors.textPrimary,
                  ),
                  title: Text(
                    isBookmarked
                        ? 'Remove from bookmarks'
                        : 'Save to bookmarks',
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onToggleBookmark();
                  },
                ),
                ListTile(
                  leading: Icon(
                    isSubscribed
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    color: colors.textPrimary,
                  ),
                  title: Text(
                    isSubscribed
                        ? 'Mute thread notifications'
                        : 'Get thread notifications',
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onToggleSubscription();
                  },
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
                    onShare();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.groups_rounded,
                    color: colors.primary,
                  ),
                  title: Text(
                    'Launch Live Focus Room for Thread',
                    style: typography.body.medium.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final room = StudyRoomEntity(
                      id: 'room-forum-${post.id}',
                      title: 'Focus Room: ${post.title}',
                      subject: post.track,
                      description:
                          'Live focus room created for thread: ${post.title}',
                      category: post.syllabusTag,
                    );
                    unawaited(
                      context.router.push(LiveStudyRoomRoute(room: room)),
                    );
                    context.showSnackBar(
                      message: 'Live Focus Room launched for this thread 🎧',
                      type: SnackBarType.success,
                    );
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
                    await onCopyLink();
                  },
                ),
                if (isAuthor) ...[
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
                      onEditPost();
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
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDeletePost();
                    },
                  ),
                ] else
                  ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: colors.error,
                    ),
                    title: Text(
                      'Report Thread',
                      style: typography.body.medium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onReport();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
