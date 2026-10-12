import 'dart:async';

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
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Displays an adaptive modal sheet for editing a forum discussion post.
Future<void> showEditPostModalSheet(
  BuildContext context, {
  required ForumPostEntity post,
  CommunityRepository? communityRepository,
  CommunityHubBloc? communityHubBloc,
}) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;
  final repo =
      communityRepository ??
      (locator.isRegistered<CommunityRepository>()
          ? locator<CommunityRepository>()
          : null);
  final hubBloc =
      communityHubBloc ??
      (locator.isRegistered<CommunityHubBloc>()
          ? locator<CommunityHubBloc>()
          : null);

  final titleController = TextEditingController(text: post.title);
  final contentController = TextEditingController(text: post.content);
  final isSubmitting = ValueNotifier<bool>(false);

  return AppAdaptiveSheet.showModal<void>(
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
                  controller: titleController,
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
                  controller: contentController,
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
                          final newTitle = titleController.text.trim();
                          final newContent = contentController.text.trim();
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

                          if (repo == null) return;

                          isSubmitting.value = true;
                          final res = await repo.updateForumPost(
                            postId: post.id,
                            title: newTitle,
                            content: newContent,
                          );
                          isSubmitting.value = false;

                          res.fold(
                            (failure) {
                              if (context.mounted) {
                                context.showSnackBar(
                                  message:
                                      failure.message ??
                                      'Failed to update discussion',
                                  type: SnackBarType.error,
                                );
                              }
                            },
                            (updated) {
                              hubBloc?.add(
                                const RefreshForumPostsEvent(),
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
