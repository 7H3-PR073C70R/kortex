import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_composer_attachments_preview.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_composer_dialogs.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_post_vote_pill.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating quick-reply composer bar at the bottom of the forum thread detail page.
class ForumThreadReplyComposerBar extends StatelessWidget {
  const ForumThreadReplyComposerBar({
    required this.replyController,
    required this.focusNode,
    required this.replyRecorderController,
    required this.replyingToReply,
    required this.showFormattingTools,
    required this.isRecordingReplyVoice,
    required this.isReplyVoiceLocked,
    required this.replyVoiceNoteDuration,
    required this.replyVoiceTranscript,
    required this.replyVoiceNoteUrl,
    required this.replyImages,
    required this.isAnonymousReply,
    required this.isSubmitting,
    required this.isGeneratingAiHint,
    required this.onApplyFormat,
    required this.onInsertSnippet,
    required this.onGenerateAiHint,
    required this.onSubmitReply,
    this.audioRecordingService,
    super.key,
  });

  final TextEditingController replyController;
  final FocusNode focusNode;
  final VoiceNoteRecorderController replyRecorderController;
  final ValueNotifier<ForumReplyEntity?> replyingToReply;
  final ValueNotifier<bool> showFormattingTools;
  final ValueNotifier<bool> isRecordingReplyVoice;
  final ValueNotifier<bool> isReplyVoiceLocked;
  final ValueNotifier<int> replyVoiceNoteDuration;
  final ValueNotifier<String> replyVoiceTranscript;
  final ValueNotifier<String?> replyVoiceNoteUrl;
  final ValueNotifier<List<String>> replyImages;
  final ValueNotifier<bool> isAnonymousReply;
  final ValueNotifier<bool> isSubmitting;
  final ValueNotifier<bool> isGeneratingAiHint;
  final void Function(String prefix, String suffix, [String placeholder])
      onApplyFormat;
  final void Function(String snippet) onInsertSnippet;
  final VoidCallback onGenerateAiHint;
  final VoidCallback onSubmitReply;
  final AudioRecordingService? audioRecordingService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final recordingService = audioRecordingService ??
        (locator.isRegistered<AudioRecordingService>()
            ? locator<AudioRecordingService>()
            : null);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Container(
          decoration: BoxDecoration(color: colors.transparent),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Active Target Context Banner (Replying to @username)
                if (replyingToReply.value != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.primary.withAlpha(50),
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
                        Expanded(
                          child: Text(
                            'Replying to @${replyingToReply.value!.authorName}',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ShrinkableButton(
                          onTap: () => replyingToReply.value = null,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Quick Formatting Tools Strip
                AnimatedCrossFade(
                  crossFadeState: showFormattingTools.value
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 200),
                  secondChild: const SizedBox.shrink(),
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          QuickToolChip(
                            label: 'Math',
                            prefix: 'Σ √x',
                            isHighlighted: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              ForumComposerDialogs.showLatexSnippetDialog(
                                context,
                                onInsertSnippet,
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'AI Hint',
                            icon: Icons.auto_awesome_rounded,
                            isHighlighted: true,
                            onTap: isGeneratingAiHint.value
                                ? null
                                : onGenerateAiHint,
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Code',
                            prefix: '</>',
                            isHighlighted: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onApplyFormat('`', '`', 'code');
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Symbols',
                            prefix: 'π / θ',
                            isHighlighted: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              ForumComposerDialogs.showMathSymbolDialog(
                                context,
                                onInsertSnippet,
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Bold',
                            prefix: 'B',
                            isCodeStyle: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onApplyFormat('**', '**', 'bold text');
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Italic',
                            prefix: 'I',
                            isCodeStyle: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onApplyFormat('*', '*', 'italic text');
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Strike',
                            prefix: '~S~',
                            isCodeStyle: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onApplyFormat('~~', '~~', 'strikethrough');
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Quote',
                            prefix: '”',
                            isCodeStyle: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onApplyFormat('\n> ', '\n', 'quoted text');
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'List',
                            prefix: '•',
                            isCodeStyle: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onInsertSnippet('\n- ');
                            },
                          ),
                          const SizedBox(width: 6),
                          QuickToolChip(
                            label: 'Block',
                            prefix: '</>',
                            isCodeStyle: true,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              onInsertSnippet(
                                '\n```\n// Code or equation here\n```\n',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Recording indicator banner
                if (isRecordingReplyVoice.value) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: VoiceRecordingBannerWidget(
                      isLocked: isReplyVoiceLocked.value,
                      durationSeconds: replyVoiceNoteDuration.value,
                      transcriptText: replyVoiceTranscript.value,
                      amplitudeStream: recordingService?.amplitudeStream,
                      onCancel: () {
                        unawaited(replyRecorderController.cancel());
                      },
                      onDone: () {
                        unawaited(replyRecorderController.finish());
                      },
                    ),
                  ),
                ],

                // Attachments preview (voice note & image thumbnails)
                ForumComposerAttachmentsPreview(
                  replyVoiceNoteUrl: replyVoiceNoteUrl,
                  replyVoiceNoteDuration: replyVoiceNoteDuration,
                  replyVoiceTranscript: replyVoiceTranscript,
                  replyImages: replyImages,
                  fallbackText: replyController.text.trim(),
                ),

                // Input Row & Send Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 10),
                  child: Row(
                    children: [
                      // 1. Attach Button -> opens image attachment directly
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.attach_file_rounded,
                          size: 20,
                          color: replyImages.value.isNotEmpty
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        tooltip: l10n.tooltipAttachImage,
                        onPressed: () async {
                          unawaited(HapticFeedback.lightImpact());
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1920,
                              maxHeight: 1920,
                              imageQuality: 85,
                            );
                            if (photo != null && photo.path.isNotEmpty) {
                              replyImages.value = [
                                ...replyImages.value,
                                photo.path,
                              ];
                            }
                          } on Object catch (e, st) {
                            AppLogger.recordNonFatal(e, st);
                          }
                        },
                      ),

                      // 2. Voice Note Recorder
                      VoiceNoteRecorderWidget(
                        compact: true,
                        controller: replyController,
                        recorderController: replyRecorderController,
                        onRecordingStateChanged: ({
                          required isRecording,
                          required isLocked,
                          required durationSeconds,
                          required transcript,
                        }) {
                          isRecordingReplyVoice.value = isRecording;
                          isReplyVoiceLocked.value = isLocked;
                          replyVoiceNoteDuration.value = durationSeconds;
                          replyVoiceTranscript.value = transcript;
                        },
                        onRecordingComplete: ({
                          required audioUrl,
                          required durationSeconds,
                          required transcript,
                        }) {
                          replyVoiceNoteUrl.value = audioUrl;
                          replyVoiceNoteDuration.value = durationSeconds;
                          if (transcript.trim().isNotEmpty) {
                            replyVoiceTranscript.value = transcript.trim();
                          }
                        },
                        onCancel: () {
                          replyVoiceNoteUrl.value = null;
                          replyVoiceNoteDuration.value = 0;
                          replyVoiceTranscript.value = '';
                        },
                      ),

                      // 3. Compact Styling Tools Toggle Button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          showFormattingTools.value
                              ? Icons.text_format_rounded
                              : Icons.text_fields_rounded,
                          size: 19,
                          color: showFormattingTools.value
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        tooltip: showFormattingTools.value
                            ? 'Hide tools'
                            : 'Writing & Math Tools',
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          showFormattingTools.value =
                              !showFormattingTools.value;
                        },
                      ),
                      const SizedBox(width: 2),

                      // 3b. Anonymous Reply Mode Toggle
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          isAnonymousReply.value
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 19,
                          color: isAnonymousReply.value
                              ? colors.warning
                              : colors.textSecondary,
                        ),
                        tooltip: isAnonymousReply.value
                            ? 'Replying Anonymously (Tap to switch)'
                            : 'Reply Anonymously',
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          isAnonymousReply.value = !isAnonymousReply.value;
                        },
                      ),
                      const SizedBox(width: 4),

                      // 4. Text Field
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: TextField(
                            controller: replyController,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: typography.body.regular.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: isRecordingReplyVoice.value
                                  ? 'Recording voice note…'
                                  : replyingToReply.value != null
                                  ? 'Reply to @${replyingToReply.value!.authorName}…'
                                  : 'Add a reply…',
                              hintStyle: typography.body.regular.copyWith(
                                color: isRecordingReplyVoice.value
                                    ? colors.error.withAlpha(180)
                                    : colors.textSecondary,
                                fontSize: 14,
                                overflow: TextOverflow.ellipsis,
                              ),
                              filled: true,
                              fillColor: isRecordingReplyVoice.value
                                  ? colors.error.withAlpha(isDark ? 30 : 16)
                                  : isDark
                                  ? colors.surfaceSecondary.withAlpha(160)
                                  : colors.surfaceSecondary.withAlpha(130),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: isRecordingReplyVoice.value
                                      ? colors.error.withAlpha(180)
                                      : colors.surfaceBorder.withAlpha(
                                          isDark ? 60 : 35,
                                        ),
                                  width: isRecordingReplyVoice.value ? 1.5 : 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: isRecordingReplyVoice.value
                                      ? colors.error.withAlpha(180)
                                      : colors.surfaceBorder.withAlpha(
                                          isDark ? 60 : 35,
                                        ),
                                  width: isRecordingReplyVoice.value ? 1.5 : 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: isRecordingReplyVoice.value
                                      ? colors.error
                                      : colors.primary.withAlpha(160),
                                  width: 1.8,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 5. Send Button
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return AnimatedScale(
                            scale: isHovered ? 1.06 : 1,
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            child: child,
                          );
                        },
                        child: ShrinkableButton(
                          onTap: isSubmitting.value ? null : onSubmitReply,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                            ),
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: AppMotion.snappy,
                              switchInCurve: AppMotion.easeOutCubic,
                              child: isSubmitting.value
                                  ? AppLogoLoader(
                                      key: const ValueKey('submitting_loader'),
                                      size: 16,
                                      color: colors.white,
                                      showMessage: false,
                                    )
                                  : Icon(
                                      Icons.send_rounded,
                                      key: const ValueKey('send_icon'),
                                      color: colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
