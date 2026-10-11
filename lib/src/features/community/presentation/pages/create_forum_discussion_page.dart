import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_attachments_section.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_autosave_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_editor_section.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_header_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_policies_section.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_submission_coordinator.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class CreateForumDiscussionPage extends HookWidget {
  const CreateForumDiscussionPage({
    this.initialTrack = 'WAEC',
    this.initialTitle,
    this.initialContent,
    this.initialTags,
    this.karmaBounty = 0,
    this.onSubmit,
    this.userStorageService,
    this.communityRepository,
    this.mediaUploadService,
    this.streamSyllabotResponseUseCase,
    this.audioRecordingService,
    super.key,
  });

  final String initialTrack;
  final String? initialTitle;
  final String? initialContent;
  final List<String>? initialTags;
  final int karmaBounty;
  final void Function({
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
  })? onSubmit;
  final UserStorageService? userStorageService;
  final CommunityRepository? communityRepository;
  final MediaUploadService? mediaUploadService;
  final StreamSyllabotResponseUseCase? streamSyllabotResponseUseCase;
  final AudioRecordingService? audioRecordingService;

  static const List<String> availableTracks = [
    'WAEC',
    'JAMB',
    'Cambridge',
    'SAT',
    'DesignEngineering',
    'General',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final effectiveUserStorage = userStorageService ??
        (locator.isRegistered<UserStorageService>()
            ? locator<UserStorageService>()
            : null);
    final userDisplayName =
        effectiveUserStorage?.getUserDisplayName() ?? 'Elena Rostova';

    final titleController = useTextEditingController(text: initialTitle ?? '');
    final contentController = useTextEditingController(
      text: initialContent ?? '',
    );
    final tagInputController = useTextEditingController();

    final selectedTrack = useState<String>(
      initialTrack.isEmpty ? 'WAEC' : initialTrack,
    );
    final tags = useState<List<String>>(initialTags ?? []);
    final isAnonymous = useState<bool>(false);
    final isRichPreview = useState<bool>(false);
    final isAiBannerVisible = useState<bool>(true);
    final allowAiHints = useState<bool>(true);
    final notifyVerifiedSolution = useState<bool>(true);
    final isPublishing = useState<bool>(false);
    final isGeneratingAi = useState<bool>(false);
    final isAddingTag = useState<bool>(false);

    // Media & Voice note attachments state
    final attachedImages = useState<List<String>>([]);
    final recordedVoiceNoteUrl = useState<String?>(null);
    final voiceNoteDurationSeconds = useState<int>(0);
    final recordedVoiceNoteTranscript = useState<String?>(null);
    final isRecordingVoice = useState<bool>(false);
    final voiceRecordingDuration = useState<int>(0);
    final voiceRecorderController = useMemoized(
      VoiceNoteRecorderController.new,
    );

    final characterCount = useState<int>(0);
    final lastSavedTime = useState<String>('Draft');

    useEffect(() {
      void listener() {
        characterCount.value =
            titleController.text.length + contentController.text.length;
      }

      titleController.addListener(listener);
      contentController.addListener(listener);
      return () {
        titleController.removeListener(listener);
        contentController.removeListener(listener);
      };
    }, [titleController, contentController]);

    void insertSnippet(String snippet) {
      final text = contentController.text;
      final sel = contentController.selection;
      if (sel.isValid && sel.start >= 0) {
        final newText = text.replaceRange(sel.start, sel.end, snippet);
        contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: sel.start + snippet.length,
          ),
        );
      } else {
        contentController.text = '$text$snippet';
      }
      unawaited(HapticFeedback.lightImpact());
    }

    void applyFormatting(String prefix, [String suffix = '']) {
      final text = contentController.text;
      final sel = contentController.selection;
      if (sel.isValid && sel.start >= 0 && sel.end > sel.start) {
        final selectedText = text.substring(sel.start, sel.end);
        final formatted = '$prefix$selectedText$suffix';
        final newText = text.replaceRange(sel.start, sel.end, formatted);
        contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: sel.start + prefix.length,
            extentOffset: sel.start + prefix.length + selectedText.length,
          ),
        );
      } else {
        final insertText = '$prefix$suffix';
        final cursorPos =
            sel.isValid && sel.start >= 0 ? sel.start : text.length;
        final newText = text.replaceRange(cursorPos, cursorPos, insertText);
        contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorPos + prefix.length),
        );
      }
      unawaited(HapticFeedback.lightImpact());
    }

    void handlePublish() {
      unawaited(
        CreateDiscussionSubmissionCoordinator.publishDiscussion(
          context: context,
          title: titleController.text.trim(),
          content: contentController.text.trim(),
          selectedTrack: selectedTrack.value,
          tags: tags.value,
          attachedImages: attachedImages.value,
          recordedVoiceNoteUrl: recordedVoiceNoteUrl.value,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds.value,
          recordedVoiceNoteTranscript: recordedVoiceNoteTranscript.value,
          isAnonymous: isAnonymous.value,
          isPublishing: isPublishing,
          onSubmit: onSubmit,
          communityRepository: communityRepository,
          mediaUploadService: mediaUploadService,
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.surfacePrimary,
        elevation: 0,
        leadingWidth: 96,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: PlatformHoverBuilder(
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.05 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: ShrinkableButton(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: typography.body.medium.copyWith(
                      color: isHovered ? colors.primary : colors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'New Discussion',
                style: typography.headline.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: PlatformHoverBuilder(
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.03 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: ShrinkableButton(
                  onTap: isPublishing.value ? null : handlePublish,
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: AppRadius.radiusPanel,
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isHovered ? 50 : 20),
                          blurRadius: isHovered ? 12 : 8,
                          offset: Offset(0, isHovered ? 4 : 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPublishing.value)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.white,
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            'Publish',
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Track selector, author avatar, AI banner
                      CreateDiscussionHeaderBar(
                        selectedTrack: selectedTrack.value,
                        availableTracks: availableTracks,
                        onTrackChanged: (t) => selectedTrack.value = t,
                        isAnonymous: isAnonymous.value,
                        onToggleAnonymous: () {
                          isAnonymous.value = !isAnonymous.value;
                          unawaited(HapticFeedback.selectionClick());
                        },
                        userDisplayName: userDisplayName,
                        isAiBannerVisible: isAiBannerVisible.value,
                        onDismissAiBanner: () =>
                            isAiBannerVisible.value = false,
                      ),

                      // Post Title Section
                      Text(
                        'Post Title',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 35 : 20),
                          ),
                        ),
                        child: TextField(
                          controller: titleController,
                          style: typography.headline.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Algorithmic latency in distributed systems...',
                            hintStyle: typography.body.regular.copyWith(
                              color: colors.textSecondary.withAlpha(120),
                              fontSize: 15,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Problem Statement & Working Steps Editor
                      CreateDiscussionEditorSection(
                        titleController: titleController,
                        contentController: contentController,
                        isRichPreview: isRichPreview,
                        isGeneratingAi: isGeneratingAi,
                        onApplyFormatting: applyFormatting,
                        onInsertSnippet: insertSnippet,
                        streamSyllabotResponseUseCase:
                            streamSyllabotResponseUseCase,
                      ),
                      const SizedBox(height: 18),

                      // Media Attachments Section
                      CreateDiscussionAttachmentsSection(
                        attachedImages: attachedImages.value,
                        onImagesChanged: (imgs) => attachedImages.value = imgs,
                        recordedVoiceNoteUrl: recordedVoiceNoteUrl.value,
                        voiceNoteDurationSeconds: voiceNoteDurationSeconds.value,
                        recordedVoiceNoteTranscript:
                            recordedVoiceNoteTranscript.value,
                        isRecordingVoice: isRecordingVoice,
                        voiceRecordingDuration: voiceRecordingDuration,
                        voiceRecorderController: voiceRecorderController,
                        contentController: contentController,
                        audioRecordingService: audioRecordingService,
                        onVoiceNoteRecorded: ({
                          required audioUrl,
                          required durationSeconds,
                          required transcript,
                        }) {
                          recordedVoiceNoteUrl.value = audioUrl;
                          voiceNoteDurationSeconds.value = durationSeconds;
                          recordedVoiceNoteTranscript.value = transcript;
                        },
                        onVoiceNoteDeleted: () {
                          recordedVoiceNoteUrl.value = null;
                          voiceNoteDurationSeconds.value = 0;
                          recordedVoiceNoteTranscript.value = null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Discussion Policies Section
                      CreateDiscussionPoliciesSection(
                        tags: tags.value,
                        onTagsChanged: (t) => tags.value = t,
                        isAddingTag: isAddingTag,
                        tagInputController: tagInputController,
                        isAnonymous: isAnonymous.value,
                        onAnonymousChanged: (val) => isAnonymous.value = val,
                        allowAiHints: allowAiHints.value,
                        onAllowAiHintsChanged: (val) =>
                            allowAiHints.value = val,
                        notifyVerifiedSolution: notifyVerifiedSolution.value,
                        onNotifyVerifiedSolutionChanged: (val) =>
                            notifyVerifiedSolution.value = val,
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Autosave Bar
          CreateDiscussionAutosaveBar(
            lastSavedTime: lastSavedTime.value,
            characterCount: characterCount.value,
            onDiscard: () {
              titleController.clear();
              contentController.clear();
              attachedImages.value = [];
              recordedVoiceNoteUrl.value = null;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
