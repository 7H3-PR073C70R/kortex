import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Displays an author action menu (Edit, Delete) or Report menu for any forum reply.
void showForumReplyOptionsMenu(
  BuildContext context,
  ForumReplyEntity reply, {
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  UserStorageService? userStorage,
}) {
  unawaited(HapticFeedback.lightImpact());
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  final effectiveStorage = userStorage ??
      (locator.isRegistered<UserStorageService>()
          ? locator<UserStorageService>()
          : null);
  final currentUserId = effectiveStorage?.getUserId();
  final currentUserName = effectiveStorage?.getUserDisplayName() ?? '';
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
