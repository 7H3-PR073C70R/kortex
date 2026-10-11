import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';
import 'package:kortex/src/features/community/domain/services/forum_duplicate_detector.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/moderation_feedback_dialog.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';

/// Coordinator encapsulating discussion content moderation, duplicate detection,
/// media uploading, Syllabot AI formatting assist, and post publishing.
abstract final class CreateDiscussionSubmissionCoordinator {
  static Future<void> runAiFormatAssist({
    required BuildContext context,
    required TextEditingController titleController,
    required TextEditingController contentController,
    required ValueNotifier<bool> isGeneratingAi,
    StreamSyllabotResponseUseCase? streamUseCase,
  }) async {
    if (isGeneratingAi.value) return;
    isGeneratingAi.value = true;
    unawaited(HapticFeedback.mediumImpact());

    final effectiveStreamUseCase = streamUseCase ??
        (locator.isRegistered<StreamSyllabotResponseUseCase>()
            ? locator<StreamSyllabotResponseUseCase>()
            : null);

    try {
      final prompt =
          'You are an elite academic assistant. Format the following draft problem into clear LaTeX formulas and concise steps:\n\n'
          '${contentController.text.isNotEmpty ? contentController.text : titleController.text}';
      var generated = '';

      if (effectiveStreamUseCase != null) {
        try {
          final stream = effectiveStreamUseCase.call(
            prompt: prompt,
            sessionId: 'draft-${DateTime.now().millisecondsSinceEpoch}',
            socraticMode: SocraticMode.stepByStep,
            preferredEngine: ExecutionEngineType.cloudRemote,
          );
          final buffer = StringBuffer();
          await stream
              .timeout(
                const Duration(seconds: 12),
                onTimeout: (s) => s.close(),
              )
              .forEach(buffer.write);
          generated = buffer.toString().trim();
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }

        if (generated.isEmpty) {
          try {
            final localStream = effectiveStreamUseCase.call(
              prompt: prompt,
              sessionId: 'draft-local-${DateTime.now().millisecondsSinceEpoch}',
              socraticMode: SocraticMode.stepByStep,
              preferredEngine: ExecutionEngineType.localOnDevice,
            );
            final buffer = StringBuffer();
            await localStream
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: (s) => s.close(),
                )
                .forEach(buffer.write);
            generated = buffer.toString().trim();
          } on Object catch (e, st) {
            AppLogger.recordNonFatal(e, st);
          }
        }
      }

      if (generated.isNotEmpty && context.mounted) {
        contentController.text = generated;
        context.showSnackBar(
          message: 'Threadline AI formatted your problem steps ✨',
        );
      }
    } on Object catch (_) {
      if (context.mounted) {
        context.showSnackBar(message: 'AI assistance ready in editor');
      }
    } finally {
      isGeneratingAi.value = false;
    }
  }

  static Future<void> publishDiscussion({
    required BuildContext context,
    required String title,
    required String content,
    required String selectedTrack,
    required List<String> tags,
    required List<String> attachedImages,
    required String? recordedVoiceNoteUrl,
    required int voiceNoteDurationSeconds,
    required String? recordedVoiceNoteTranscript,
    required bool isAnonymous,
    required ValueNotifier<bool> isPublishing,
    void Function({
      required String title,
      required String content,
      required String track,
      String? latexContent,
      bool isQuestion,
      String syllabusTag,
      List<String>? tags,
      List<String>? mediaUrls,
      String? voiceNoteUrl,
      int? voiceNoteDurationSeconds,
      bool isAnonymous,
    })? onSubmit,
    CommunityRepository? communityRepository,
    MediaUploadService? mediaUploadService,
  }) async {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (title.isEmpty) {
      context.showSnackBar(message: 'Please enter a post title');
      return;
    }
    if (content.isEmpty && attachedImages.isEmpty && recordedVoiceNoteUrl == null) {
      context.showSnackBar(
        message: 'Please provide problem details, images, or voice note',
      );
      return;
    }

    // Content safety & anti-abuse moderation check
    const moderationService = ContentModerationService();
    final modResult = moderationService.validatePost(
      title: title,
      content: content,
    );
    if (!modResult.isValid) {
      unawaited(
        ModerationFeedbackDialog.show(
          context,
          result: modResult,
          contentTarget: 'discussion',
        ),
      );
      return;
    }

    final sanitizedTitle = ContentModerationService.sanitizeText(title);
    final sanitizedContent = ContentModerationService.sanitizeText(content);

    // Duplicate post prevention check across existing state
    final currentPosts = context.read<CommunityHubBloc>().state.forumPosts;
    final duplicateMatch = ForumDuplicateDetector.findExactOrHighMatch(
      title: sanitizedTitle,
      posts: currentPosts,
      track: selectedTrack,
    );

    if (duplicateMatch != null) {
      context.showSnackBar(
        message:
            'A highly similar discussion thread "${duplicateMatch.title}" already exists in $selectedTrack. Please join the existing discussion!',
        type: SnackBarType.error,
      );
      return;
    }

    isPublishing.value = true;
    unawaited(HapticFeedback.mediumImpact());

    // Extract LaTeX if present
    String? latexSnippet;
    if (content.contains(r'$$') ||
        content.contains(r'$') ||
        content.contains(r'\')) {
      final reg = RegExp(r'\$\$(.*?)\$\$|\$(.*?)\$', dotAll: true);
      final match = reg.firstMatch(content);
      if (match != null) {
        latexSnippet = match.group(0);
      }
    }

    // Show publishing loader modal
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: colors.black.withAlpha(160),
        builder: (dialogCtx) {
          return PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor:
                  isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogoLoader(size: 56, showMessage: false),
                    const SizedBox(height: 18),
                    Text(
                      'Publishing Discussion...',
                      style: typography.headline.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sharing your insights with scholars in $selectedTrack',
                      textAlign: TextAlign.center,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    final effectiveUploadService = mediaUploadService ??
        (locator.isRegistered<MediaUploadService>()
            ? locator<MediaUploadService>()
            : null);

    // Server-side R2 upload for local image & voice note files
    var finalMediaUrls = <String>[];
    if (attachedImages.isNotEmpty) {
      if (effectiveUploadService != null) {
        for (final imgPath in attachedImages) {
          if (imgPath.startsWith('http://') || imgPath.startsWith('https://')) {
            finalMediaUrls.add(imgPath);
          } else {
            try {
              final r2Url = await effectiveUploadService.uploadMedia(
                pathOrUrl: imgPath,
                file: kIsWeb ? null : File(imgPath),
                mediaType: ForumMediaType.image,
              );
              finalMediaUrls.add(r2Url);
            } on Object catch (_) {
              finalMediaUrls.add(imgPath);
            }
          }
        }
      } else {
        finalMediaUrls = List<String>.from(attachedImages);
      }
    }

    var finalVoiceNoteUrl = recordedVoiceNoteUrl;
    if (finalVoiceNoteUrl != null &&
        !finalVoiceNoteUrl.startsWith('http://') &&
        !finalVoiceNoteUrl.startsWith('https://') &&
        effectiveUploadService != null) {
      try {
        final r2Url = await effectiveUploadService.uploadMedia(
          pathOrUrl: finalVoiceNoteUrl,
          file: kIsWeb ? null : File(finalVoiceNoteUrl),
          mediaType: ForumMediaType.voice,
        );
        finalVoiceNoteUrl = r2Url;
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    if (onSubmit != null) {
      onSubmit(
        title: sanitizedTitle,
        content:
            sanitizedContent.isNotEmpty ? sanitizedContent : sanitizedTitle,
        track: selectedTrack,
        latexContent: latexSnippet,
        isQuestion: true,
        syllabusTag: tags.isNotEmpty ? tags.first : 'General',
        tags: tags,
        mediaUrls: finalMediaUrls,
        voiceNoteUrl: finalVoiceNoteUrl,
        voiceNoteDurationSeconds:
            voiceNoteDurationSeconds > 0 ? voiceNoteDurationSeconds : null,
        isAnonymous: isAnonymous,
      );
      isPublishing.value = false;
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.showSnackBar(
          message: 'Discussion published successfully! ✨',
          type: SnackBarType.success,
        );
        Navigator.of(context).pop(true);
      }
      return;
    }

    final effectiveRepo = communityRepository ??
        (locator.isRegistered<CommunityRepository>()
            ? locator<CommunityRepository>()
            : null);

    if (effectiveRepo == null) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.showSnackBar(
          message: 'Community service unavailable',
          type: SnackBarType.error,
        );
      }
      isPublishing.value = false;
      return;
    }

    try {
      final result = await effectiveRepo.createForumPost(
        title: sanitizedTitle,
        content:
            sanitizedContent.isNotEmpty ? sanitizedContent : sanitizedTitle,
        track: selectedTrack,
        latexContent: latexSnippet,
        isQuestion: true,
        syllabusTag: tags.isNotEmpty ? tags.first : 'General',
        tags: tags,
        mediaUrls: finalMediaUrls,
        voiceNoteUrl: finalVoiceNoteUrl,
        voiceNoteDurationSeconds:
            voiceNoteDurationSeconds > 0 ? voiceNoteDurationSeconds : null,
        voiceNoteTranscript:
            recordedVoiceNoteTranscript?.trim().isNotEmpty == true
                ? recordedVoiceNoteTranscript!.trim()
                : null,
        isAnonymous: isAnonymous,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      isPublishing.value = false;

      result.fold(
        (failure) {
          if (context.mounted) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to publish discussion',
              type: SnackBarType.error,
            );
          }
        },
        (post) {
          final vnUrl = post.voiceNoteUrl;
          if (vnUrl != null &&
              vnUrl.trim().isNotEmpty &&
              effectiveUploadService != null) {
            unawaited(
              effectiveUploadService.triggerVoiceNoteTranscription(
                audioUrl: vnUrl,
                postId: post.id,
              ),
            );
          }

          try {
            final hubBloc = context.read<CommunityHubBloc>();
            hubBloc.add(
              ChangeForumSortFilterEvent(hubBloc.state.selectedForumFilter),
            );
          } on Object catch (e, st) {
            AppLogger.recordNonFatal(e, st);
          }

          if (context.mounted) {
            context.showSnackBar(
              message: 'Discussion published successfully! ✨',
              type: SnackBarType.success,
            );
            Navigator.of(context).pop(true);
          }
        },
      );
    } on Object catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.showSnackBar(
          message: 'Failed to publish discussion: $e',
          type: SnackBarType.error,
        );
      }
      isPublishing.value = false;
    }
  }
}
