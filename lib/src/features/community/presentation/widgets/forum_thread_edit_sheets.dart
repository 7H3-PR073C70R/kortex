import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/moderation_feedback_dialog.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Modal dialogs and adaptive bottom sheets for editing and deleting forum posts and replies.
abstract final class ForumThreadEditSheets {
  static Future<void> showEditPostSheet(
    BuildContext context, {
    required ForumPostEntity post,
    required CommunityRepository repository,
    required ValueChanged<ForumPostEntity> onUpdated,
  }) async {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final titleEditController = TextEditingController(text: post.title);
    final contentEditController = TextEditingController(text: post.content);
    final isSubmittingEdit = ValueNotifier<bool>(false);

    await AppAdaptiveSheet.showModal<void>(
      context: context,
      builder: (sheetCtx) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetCtx);
        return Container(
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
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: isDesktop
                ? 20
                : (MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: isSubmittingEdit,
            builder: (ctx, isSaving, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Discussion',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleEditController,
                    enabled: !isSaving,
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentEditController,
                    enabled: !isSaving,
                    maxLines: 5,
                    style: typography.body.regular.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final newTitle = titleEditController.text.trim();
                            final newContent = contentEditController.text.trim();
                            if (newTitle.isEmpty || newContent.isEmpty) {
                              return;
                            }

                            const mod = ContentModerationService();
                            final modRes = mod.validatePost(
                              title: newTitle,
                              content: newContent,
                            );
                            if (!modRes.isValid) {
                              unawaited(
                                ModerationFeedbackDialog.show(
                                  context,
                                  result: modRes,
                                  contentTarget: 'discussion',
                                ),
                              );
                              return;
                            }

                            isSubmittingEdit.value = true;
                            final res = await repository.updateForumPost(
                              postId: post.id,
                              title: newTitle,
                              content: newContent,
                            );
                            isSubmittingEdit.value = false;

                            res.fold(
                              (failure) {
                                if (context.mounted) {
                                  context.showSnackBar(
                                    message: failure.message ??
                                        'Failed to update discussion',
                                    type: SnackBarType.error,
                                  );
                                }
                              },
                              (updated) {
                                onUpdated(
                                  post.copyWith(
                                    title: updated.title,
                                    content: updated.content,
                                  ),
                                );
                                if (context.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                  context.showSnackBar(
                                    message: 'Discussion updated',
                                  );
                                }
                              },
                            );
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> showEditReplySheet(
    BuildContext context, {
    required ForumReplyEntity reply,
    required CommunityRepository repository,
    required ValueChanged<ForumReplyEntity> onUpdated,
  }) async {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final editController = TextEditingController(text: reply.content);
    final isSubmitting = ValueNotifier<bool>(false);

    await AppAdaptiveSheet.showModal<void>(
      context: context,
      builder: (sheetCtx) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetCtx);
        return Container(
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
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: isDesktop
                ? 20
                : (MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: isSubmitting,
            builder: (ctx, isSaving, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Reply',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editController,
                    enabled: !isSaving,
                    maxLines: 4,
                    style: typography.body.regular.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Reply',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final newText = editController.text.trim();
                            if (newText.isEmpty) return;

                            const mod = ContentModerationService();
                            final modRes = mod.validateReply(
                              content: newText,
                            );
                            if (!modRes.isValid) {
                              unawaited(
                                ModerationFeedbackDialog.show(
                                  context,
                                  result: modRes,
                                  contentTarget: 'reply',
                                ),
                              );
                              return;
                            }

                            isSubmitting.value = true;
                            final res = await repository.updateForumReply(
                              replyId: reply.id,
                              content: newText,
                            );
                            isSubmitting.value = false;

                            res.fold(
                              (failure) {
                                if (context.mounted) {
                                  context.showSnackBar(
                                    message: failure.message ??
                                        'Failed to update reply',
                                    type: SnackBarType.error,
                                  );
                                }
                              },
                              (updated) {
                                onUpdated(
                                  reply.copyWith(content: updated.content),
                                );
                                if (context.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                  context.showSnackBar(
                                    message: 'Reply updated',
                                  );
                                }
                              },
                            );
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> confirmDeletePost(
    BuildContext context, {
    required String postId,
    required CommunityRepository repository,
  }) async {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor:
            isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Discussion?',
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'This action cannot be undone. Are you sure you want to permanently delete this discussion?',
          style: typography.body.regular.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
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
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final res = await repository.deleteForumPost(postId);
      res.fold(
        (failure) {
          if (context.mounted) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to delete discussion',
              type: SnackBarType.error,
            );
          }
        },
        (_) {
          if (locator.isRegistered<CommunityHubBloc>()) {
            locator<CommunityHubBloc>().add(DeleteForumPostEvent(postId));
          }
          if (context.mounted) {
            context.showSnackBar(message: 'Discussion deleted');
            unawaited(context.router.maybePop());
          }
        },
      );
    }
  }

  static Future<void> confirmDeleteReply(
    BuildContext context, {
    required String postId,
    required ForumReplyEntity reply,
    required CommunityRepository repository,
    required VoidCallback onDeleted,
  }) async {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor:
            isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Reply?',
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete this reply?',
          style: typography.body.regular.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
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
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final res = await repository.deleteForumReply(
        postId: postId,
        replyId: reply.id,
      );
      res.fold(
        (failure) {
          if (context.mounted) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to delete reply',
              type: SnackBarType.error,
            );
          }
        },
        (_) {
          onDeleted();
          if (context.mounted) {
            context.showSnackBar(message: 'Reply deleted');
          }
        },
      );
    }
  }
}
