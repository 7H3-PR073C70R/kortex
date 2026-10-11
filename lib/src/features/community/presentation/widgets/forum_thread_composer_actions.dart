import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/moderation_feedback_dialog.dart';

/// Helper actions for rich-text editing in the forum reply composer.
class ForumComposerFormatting {
  const ForumComposerFormatting._();

  /// Inserts a markdown snippet or LaTeX symbol at the current cursor position.
  static void insertSnippet(
    TextEditingController controller,
    FocusNode focusNode,
    String snippet,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        snippet,
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + snippet.length,
        ),
      );
    } else {
      controller
        ..text = '$text$snippet'
        ..selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
    }
    focusNode.requestFocus();
  }

  /// Wraps the current selection with prefix and suffix delimiters (e.g. bold, italics, code).
  static void applyFormat(
    TextEditingController controller,
    FocusNode focusNode,
    String prefix,
    String suffix, [
    String placeholder = '',
  ]) {
    final text = controller.text;
    final selection = controller.selection;
    var effectivePrefix = prefix;

    final start = selection.isValid && selection.start >= 0
        ? selection.start
        : text.length;

    if (effectivePrefix.startsWith('\n')) {
      if (start == 0 || (start > 0 && text[start - 1] == '\n')) {
        effectivePrefix = effectivePrefix.substring(1);
      }
    }

    if (selection.isValid &&
        selection.start >= 0 &&
        selection.end > selection.start) {
      final selectedText = text.substring(selection.start, selection.end);
      final replacement = '$effectivePrefix$selectedText$suffix';
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        replacement,
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + effectivePrefix.length,
          extentOffset:
              selection.start + effectivePrefix.length + selectedText.length,
        ),
      );
    } else {
      final insertIndex = start;
      final snippet = '$effectivePrefix$placeholder$suffix';
      final newText = text.replaceRange(insertIndex, insertIndex, snippet);
      final cursorOffset = insertIndex +
          effectivePrefix.length +
          (placeholder.isNotEmpty ? placeholder.length : 0);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );
    }
    focusNode.requestFocus();
  }
}

/// Orchestrates media uploading and reply creation for forum threads.
class ForumThreadReplySubmitter {
  const ForumThreadReplySubmitter._();

  static Future<void> submitReply({
    required BuildContext context,
    required TextEditingController replyController,
    required ValueNotifier<List<String>> replyImages,
    required ValueNotifier<String?> replyVoiceNoteUrl,
    required ValueNotifier<int> replyVoiceNoteDuration,
    required ValueNotifier<String> replyVoiceTranscript,
    required ValueNotifier<bool> isAnonymousReply,
    required ValueNotifier<bool> isSubmitting,
    required ValueNotifier<ForumReplyEntity?> replyingToReply,
    required ValueNotifier<List<ForumReplyEntity>> localReplies,
    required ValueNotifier<Set<String>> expandedParentReplyIds,
    required ForumPostEntity currentPost,
    required CommunityRepository repository,
    required MediaUploadService? uploadService,
    required CommunityHubBloc? hubBloc,
  }) async {
    final text = replyController.text.trim();
    if (text.isEmpty &&
        replyImages.value.isEmpty &&
        replyVoiceNoteUrl.value == null) {
      return;
    }

    if (text.isNotEmpty) {
      const moderation = ContentModerationService();
      final modResult = moderation.validateReply(content: text);
      if (!modResult.isValid) {
        unawaited(
          ModerationFeedbackDialog.show(
            context,
            result: modResult,
            contentTarget: 'reply',
          ),
        );
        return;
      }
    }

    final sanitizedText = ContentModerationService.sanitizeText(text);
    final targetParentId = replyingToReply.value?.id;
    isSubmitting.value = true;

    var finalReplyImages = <String>[];
    if (replyImages.value.isNotEmpty) {
      if (uploadService != null) {
        for (final imgPath in replyImages.value) {
          if (imgPath.startsWith('http://') ||
              imgPath.startsWith('https://')) {
            finalReplyImages.add(imgPath);
          } else {
            try {
              final r2Url = await uploadService.uploadMedia(
                pathOrUrl: imgPath,
                file: kIsWeb ? null : File(imgPath),
                mediaType: ForumMediaType.image,
              );
              finalReplyImages.add(r2Url);
            } on Object catch (e, st) {
              AppLogger.recordNonFatal(e, st);
            }
          }
        }
      } else {
        finalReplyImages = replyImages.value;
      }
    }

    var finalReplyVoiceNoteUrl = replyVoiceNoteUrl.value;
    if (finalReplyVoiceNoteUrl != null &&
        !finalReplyVoiceNoteUrl.startsWith('http://') &&
        !finalReplyVoiceNoteUrl.startsWith('https://') &&
        uploadService != null) {
      try {
        final r2Url = await uploadService.uploadMedia(
          pathOrUrl: finalReplyVoiceNoteUrl,
          file: kIsWeb ? null : File(finalReplyVoiceNoteUrl),
          mediaType: ForumMediaType.voice,
        );
        finalReplyVoiceNoteUrl = r2Url;
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    final res = await repository.replyToForumPost(
      postId: currentPost.id,
      content: sanitizedText.isNotEmpty
          ? sanitizedText
          : 'Shared media attachment',
      parentReplyId: targetParentId,
      mediaUrls: finalReplyImages,
      voiceNoteUrl: finalReplyVoiceNoteUrl,
      voiceNoteDurationSeconds: replyVoiceNoteDuration.value > 0
          ? replyVoiceNoteDuration.value
          : null,
      voiceNoteTranscript: replyVoiceTranscript.value.trim().isNotEmpty
          ? replyVoiceTranscript.value.trim()
          : null,
      isAnonymous: isAnonymousReply.value,
    );
    isSubmitting.value = false;

    res.fold(
      (failure) {
        if (context.mounted) {
          context.showSnackBar(
            message: failure.message ?? failure.toString(),
            type: SnackBarType.error,
          );
        }
      },
      (createdReply) {
        replyController.clear();
        replyImages.value = [];
        replyVoiceNoteUrl.value = null;
        replyVoiceNoteDuration.value = 0;
        replyingToReply.value = null;
        isAnonymousReply.value = false;

        if (!localReplies.value.any((r) => r.id == createdReply.id)) {
          localReplies.value = [
            ...localReplies.value,
            createdReply,
          ];
        }

        final vnUrl = createdReply.voiceNoteUrl;
        if (vnUrl != null &&
            vnUrl.trim().isNotEmpty &&
            uploadService != null) {
          unawaited(
            uploadService.triggerVoiceNoteTranscription(
              audioUrl: vnUrl,
              replyId: createdReply.id,
            ),
          );
        }

        if (targetParentId != null) {
          localReplies.value = localReplies.value.map((r) {
            if (r.id == targetParentId) {
              return r.copyWith(repliesCount: r.repliesCount + 1);
            }
            return r;
          }).toList();
          expandedParentReplyIds.value = {
            ...expandedParentReplyIds.value,
            targetParentId,
          };
        }

        hubBloc?.add(
          ForumPostRepliesIncrementedEvent(
            postId: currentPost.id,
            reply: createdReply,
          ),
        );
      },
    );
  }
}
