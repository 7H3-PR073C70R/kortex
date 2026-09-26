import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/spoken_math_converter.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
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
  })?
  onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final userStorage = locator<UserStorageService>();
    final userDisplayName = userStorage.getUserDisplayName() ?? 'Elena Rostova';
    final userHandle = userDisplayName.toLowerCase().replaceAll(' ', '_');

    final titleController = useTextEditingController(text: initialTitle ?? '');
    final contentController = useTextEditingController(text: initialContent ?? '');
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
    final isRecordingVoice = useState<bool>(false);
    final recordedVoiceNoteUrl = useState<String?>(null);
    final voiceNoteDurationSeconds = useState<int>(0);
    final recordingTimer = useRef<Timer?>(null);

    final characterCount = useState<int>(0);
    final lastSavedTime = useState<String>('Draft');

    // Speech to Text handler for live voice-to-text dictation with math KaTeX conversion
    final sttHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (words) {
          if (words.trim().isNotEmpty) {
            final convertedMath =
                SpokenMathToKaTeXConverter.convertSpokenMathToKaTeX(words);
            final current = contentController.text;
            if (current.isEmpty) {
              contentController.text = convertedMath;
            } else if (!current.contains(convertedMath)) {
              contentController.text = '$current $convertedMath';
            }
          }
        },
        onListeningChanged: (listening) {
          isRecordingVoice.value = listening;
          if (listening) {
            voiceNoteDurationSeconds.value = 0;
            recordingTimer.value?.cancel();
            recordingTimer.value = Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              voiceNoteDurationSeconds.value = timer.tick;
            });
          } else {
            recordingTimer.value?.cancel();
            if (voiceNoteDurationSeconds.value > 0) {
              recordedVoiceNoteUrl.value ??= 'audio/voice_note.wav';
            }
          }
        },
        onError: (err) {
          isRecordingVoice.value = false;
          recordingTimer.value?.cancel();
        },
      ),
    );

    useEffect(() {
      return () {
        recordingTimer.value?.cancel();
        sttHandler.dispose();
      };
    }, []);

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
        final cursorPos = sel.isValid && sel.start >= 0
            ? sel.start
            : text.length;
        final newText = text.replaceRange(cursorPos, cursorPos, insertText);
        contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorPos + prefix.length),
        );
      }
      unawaited(HapticFeedback.lightImpact());
    }

    Future<void> pickImage(ImageSource source) async {
      unawaited(HapticFeedback.lightImpact());
      try {
        final picker = ImagePicker();
        final photo = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (photo != null && photo.path.isNotEmpty) {
          attachedImages.value = [...attachedImages.value, photo.path];
          if (context.mounted) {
            context.showSnackBar(message: 'Image attached ✨');
          }
        }
      } on Object catch (_) {
        if (context.mounted) {
          context.showSnackBar(message: 'Could not access photo library');
        }
      }
    }

    void showImagePickerModal() {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      Icons.photo_library_rounded,
                      color: colors.primary,
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(pickImage(ImageSource.gallery));
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.camera_alt_rounded,
                      color: colors.primary,
                    ),
                    title: Text(
                      'Take a Photo',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(pickImage(ImageSource.camera));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> toggleVoiceRecording() async {
      try {
        if (isRecordingVoice.value) {
          await sttHandler.stopListening();
          recordingTimer.value?.cancel();
          if (voiceNoteDurationSeconds.value == 0) {
            voiceNoteDurationSeconds.value = 5;
          }
          recordedVoiceNoteUrl.value ??= 'audio/voice_note.wav';
        } else {
          await sttHandler.startListening();
        }
      } on Object catch (e) {
        isRecordingVoice.value = false;
        recordingTimer.value?.cancel();
        if (context.mounted) {
          context.showSnackBar(
            message: 'Speech recognition unavailable: $e',
          );
        }
      }
    }

    void showMathFormulaSheet() {
      final formulas = [
        r'$$\mathcal{L}_{\text{cost}} = \sum_{i=1}^{k} \min_{j} \| x_i - \mu_j \|_2^2$$',
        r'$$f(x) = \int_{-\infty}^{\infty} e^{-x^2} dx$$',
        r'$$\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}$$',
        r'$$E = mc^2$$',
        r'$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$',
      ];

      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert LaTeX Formula',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...formulas.map(
                    (form) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        form,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(Icons.add_rounded, color: colors.primary),
                      onTap: () {
                        Navigator.pop(ctx);
                        insertSnippet('\n$form\n');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    void showSymbolSheet() {
      final symbols = [
        'π',
        'θ',
        'Δ',
        'α',
        'β',
        'γ',
        'λ',
        'μ',
        'σ',
        'ω',
        '≈',
        '≠',
        '≤',
        '≥',
        '±',
        '×',
        '÷',
        '∞',
        '√',
        '∫',
      ];

      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert Math & Greek Symbol',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: symbols.length,
                    itemBuilder: (ctx, idx) {
                      final sym = symbols[idx];
                      return ShrinkableButton(
                        onTap: () {
                          Navigator.pop(ctx);
                          insertSnippet(sym);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 25 : 12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.primary.withAlpha(40),
                            ),
                          ),
                          child: Text(
                            sym,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> runAiFormatAssist() async {
      if (isGeneratingAi.value) return;
      isGeneratingAi.value = true;
      unawaited(HapticFeedback.mediumImpact());
      try {
        final prompt =
            'You are an elite academic assistant. Format the following draft problem into clear LaTeX formulas and concise steps:\n\n${contentController.text.isNotEmpty ? contentController.text : titleController.text}';
        var generated = '';
        if (locator.isRegistered<StreamSyllabotResponseUseCase>()) {
          final streamUseCase = locator<StreamSyllabotResponseUseCase>();
          try {
            final stream = streamUseCase.call(
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
          } on Object catch (_) {}

          if (generated.isEmpty) {
            try {
              final localStream = streamUseCase.call(
                prompt: prompt,
                sessionId:
                    'draft-local-${DateTime.now().millisecondsSinceEpoch}',
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
            } on Object catch (_) {}
          }
        }
        if (generated.isEmpty && locator.isRegistered<LocalLlmEngineClient>()) {
          final localLlm = locator<LocalLlmEngineClient>();
          try {
            final buffer = StringBuffer();
            await localLlm
                .generate(
                  prompt: prompt,
                  systemInstruction:
                      'Format draft problem into clear LaTeX formulas and concise steps',
                )
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: (s) => s.close(),
                )
                .forEach(buffer.write);
            generated = buffer.toString().trim();
          } on Object catch (_) {}
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

    Future<void> onPublish() async {
      final title = titleController.text.trim();
      final content = contentController.text.trim();

      if (title.isEmpty) {
        context.showSnackBar(message: 'Please enter a post title');
        return;
      }
      if (content.isEmpty &&
          attachedImages.value.isEmpty &&
          recordedVoiceNoteUrl.value == null) {
        context.showSnackBar(
          message: 'Please provide problem details, images, or voice note',
        );
        return;
      }

      // Duplicate post prevention check across existing state
      final currentPosts = context.read<CommunityHubBloc>().state.forumPosts;
      final isDuplicate = currentPosts.any(
        (p) =>
            p.track.toLowerCase() == selectedTrack.value.toLowerCase() &&
            p.title.trim().toLowerCase() == title.toLowerCase(),
      );

      if (isDuplicate) {
        context.showSnackBar(
          message:
              'A discussion thread with this exact title already exists in ${selectedTrack.value}. Please join the existing discussion!',
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

      void showPublishingLoaderDialog() {
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            barrierColor: colors.black.withAlpha(160),
            builder: (dialogCtx) {
              return PopScope(
                canPop: false,
                child: Dialog(
                  backgroundColor: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
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
                        const AppLogoLoader(
                          size: 56,
                          showMessage: false,
                        ),
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
                          'Sharing your insights with scholars in ${selectedTrack.value}',
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
      }

      showPublishingLoaderDialog();

      if (onSubmit != null) {
        onSubmit!(
          title: title,
          content: content.isNotEmpty ? content : title,
          track: selectedTrack.value,
          latexContent: latexSnippet,
          isQuestion: true,
          syllabusTag: tags.value.isNotEmpty ? tags.value.first : 'General',
          tags: tags.value,
          mediaUrls: attachedImages.value,
          voiceNoteUrl: recordedVoiceNoteUrl.value,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds.value > 0
              ? voiceNoteDurationSeconds.value
              : null,
          isAnonymous: isAnonymous.value,
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

      try {
        final result = await locator<CommunityRepository>().createForumPost(
          title: title,
          content: content.isNotEmpty ? content : title,
          track: selectedTrack.value,
          latexContent: latexSnippet,
          isQuestion: true,
          syllabusTag: tags.value.isNotEmpty ? tags.value.first : 'General',
          tags: tags.value,
          mediaUrls: attachedImages.value,
          voiceNoteUrl: recordedVoiceNoteUrl.value,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds.value > 0
              ? voiceNoteDurationSeconds.value
              : null,
          isAnonymous: isAnonymous.value,
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
            try {
              final hubBloc = context.read<CommunityHubBloc>();
              hubBloc.add(
                ChangeForumSortFilterEvent(hubBloc.state.selectedForumFilter),
              );
            } on Object catch (_) {}

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
        }
        isPublishing.value = false;
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to publish discussion: $e',
            type: SnackBarType.error,
          );
        }
      }
    }

    final availableTracks = [
      'WAEC',
      'JAMB',
      'Cambridge',
      'SAT',
      'DesignEngineering',
      'General',
    ];

    return Scaffold(
      backgroundColor: isDark ? colors.surfacePrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: isDark ? colors.surfacePrimary : colors.surfacePrimary,
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
                  onTap: isPublishing.value ? null : onPublish,
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
                      // Channel / Track Dropdown & Public Discourse Pill
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(isDark ? 35 : 20),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedTrack.value,
                                  isDense: true,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 13,
                                  ),
                                  dropdownColor: isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfacePrimary,
                                  items: availableTracks
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_outline_rounded,
                                                size: 14,
                                                color: colors.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text('c/$t'),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) selectedTrack.value = val;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfaceSecondary.withAlpha(140),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.public_rounded,
                                    size: 13,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Public Discourse',
                                    style: typography.caption.medium.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Author Info Row with Anonymous Switch
                      Row(
                        children: [
                          AnimatedSwitcher(
                            duration: AppMotion.standard,
                            switchInCurve: AppMotion.easeOutCubic,
                            switchOutCurve: AppMotion.easeOutCubic,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                            child: isAnonymous.value
                                ? AppAvatar(
                                    key: const ValueKey('anon_avatar'),
                                    customDimension: 36,
                                    fallbackIcon: Icon(
                                      Icons.masks_rounded,
                                      size: 18,
                                      color: colors.textSecondary,
                                    ),
                                    backgroundColor: isDark
                                        ? colors.surfaceSecondary
                                        : colors.surfaceTertiary,
                                    showBadge: true,
                                    badgeColor: colors.textSecondary,
                                  )
                                : AppAvatar(
                                    key: const ValueKey('public_avatar'),
                                    customDimension: 36,
                                    name: userDisplayName,
                                    showBadge: true,
                                    badgeColor: colors.success,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: AppMotion.standard,
                              switchInCurve: AppMotion.easeOutCubic,
                              child: Column(
                                key: ValueKey(isAnonymous.value),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: isAnonymous.value
                                          ? [
                                              TextSpan(
                                                text: 'Anonymous Scholar ',
                                                style: typography.body.bold
                                                    .copyWith(
                                                      color: colors.textPrimary,
                                                      fontSize: 13.5,
                                                    ),
                                              ),
                                              TextSpan(
                                                text: '@incognito',
                                                style: typography.caption.regular
                                                    .copyWith(
                                                      color: colors.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                              ),
                                            ]
                                          : [
                                              TextSpan(
                                                text: '$userDisplayName ',
                                                style: typography.body.bold
                                                    .copyWith(
                                                      color: colors.textPrimary,
                                                      fontSize: 13.5,
                                                    ),
                                              ),
                                              TextSpan(
                                                text: '@$userHandle',
                                                style: typography.caption.regular
                                                    .copyWith(
                                                      color: colors.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                              ),
                                            ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAnonymous.value
                                        ? 'Incognito • Identity hidden'
                                        : 'Author & Peer Scholar',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Quick Anonymous Mode Toggle
                          ShrinkableButton(
                            onTap: () {
                              isAnonymous.value = !isAnonymous.value;
                              unawaited(HapticFeedback.selectionClick());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isAnonymous.value
                                    ? colors.primary
                                        .withAlpha(isDark ? 40 : 25)
                                    : (isDark
                                          ? colors.surfaceSecondary
                                          : colors.surfaceSecondary.withAlpha(
                                              140,
                                            )),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isAnonymous.value
                                      ? colors.primary.withAlpha(80)
                                      : colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAnonymous.value
                                        ? Icons.masks_rounded
                                        : Icons.visibility_outlined,
                                    size: 13,
                                    color: isAnonymous.value
                                        ? colors.primary
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAnonymous.value ? 'Anonymous' : 'Public',
                                    style: typography.caption.bold.copyWith(
                                      color: isAnonymous.value
                                          ? colors.primary
                                          : colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Educational AI Assist Banner
                      if (isAiBannerVisible.value)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 30 : 15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withAlpha(isDark ? 60 : 35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.smart_toy_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Educational AI Assist',
                                      style: typography.body.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Drafting a problem? Use rich formatting, LaTeX formulas, voice notes, and images to get answers faster.',
                                      style: typography.caption.regular
                                          .copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                                onPressed: () =>
                                    isAiBannerVisible.value = false,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Post Title Section with Standard Container Padding
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

                      // Problem Statement & Working Steps Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Problem Statement & Working Steps',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              isRichPreview.value = !isRichPreview.value;
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isRichPreview.value
                                      ? Icons.edit_note_rounded
                                      : Icons.remove_red_eye_outlined,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isRichPreview.value
                                      ? 'Editor'
                                      : 'Rich Preview',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Problem Statement Container with Rich Text Toolbar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 35 : 20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // RICH TEXT FORMATTING TOOLBAR
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(
                                  isDark ? 15 : 8,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(13),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: colors.primary.withAlpha(
                                      isDark ? 25 : 15,
                                    ),
                                  ),
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.format_bold_rounded,
                                      tooltip: l10n.tooltipBold,
                                      onTap: () => applyFormatting('**', '**'),
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.format_italic_rounded,
                                      tooltip: l10n.tooltipItalic,
                                      onTap: () => applyFormatting('*', '*'),
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.strikethrough_s_rounded,
                                      tooltip: l10n.tooltipStrikethrough,
                                      onTap: () => applyFormatting('~~', '~~'),
                                    ),
                                    _buildFormatDivider(context),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.title_rounded,
                                      tooltip: l10n.tooltipHeading,
                                      onTap: () => applyFormatting('### '),
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.code_rounded,
                                      tooltip: l10n.tooltipCodeBlock,
                                      onTap: () =>
                                          applyFormatting('```\n', '\n```'),
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.format_list_bulleted_rounded,
                                      tooltip: l10n.tooltipBulletList,
                                      onTap: () => applyFormatting('- '),
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.format_list_numbered_rounded,
                                      tooltip: l10n.tooltipNumberedList,
                                      onTap: () => applyFormatting('1. '),
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.format_quote_rounded,
                                      tooltip: l10n.tooltipQuote,
                                      onTap: () => applyFormatting('> '),
                                    ),
                                    _buildFormatDivider(context),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.functions_rounded,
                                      tooltip: l10n.tooltipLatexMath,
                                      label: 'Σ',
                                      onTap: showMathFormulaSheet,
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.pie_chart_outline_rounded,
                                      tooltip: l10n.tooltipMathSymbols,
                                      label: 'π',
                                      onTap: showSymbolSheet,
                                    ),
                                    _buildFormatActionBtn(
                                      context: context,
                                      icon: Icons.auto_awesome_rounded,
                                      tooltip: l10n.tooltipAiFormatAssist,
                                      isAccent: true,
                                      onTap: runAiFormatAssist,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Text Field / Rich Preview Area
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: isRichPreview.value
                                  ? (contentController.text.trim().isEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            child: Text(
                                              'No content to preview yet. Switch to Editor to type.',
                                              style: typography.body.regular
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                            ),
                                          )
                                        : LatexRichViewer(
                                            text: contentController.text,
                                          ))
                                  : TextField(
                                      controller: contentController,
                                      maxLines: null,
                                      minLines: 6,
                                      style: typography.body.regular.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 14.5,
                                        height: 1.5,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Explain what you are solving, working steps, equations, or code...',
                                        hintStyle: typography.body.regular
                                            .copyWith(
                                              color: colors.textSecondary
                                                  .withAlpha(
                                                    120,
                                                  ),
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        isDense: true,
                                        filled: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // MEDIA ATTACHMENTS SECTION
                      Text(
                        'MEDIA & AUDIO ATTACHMENTS',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Media action buttons row (Add Image & Voice Note STT)
                      Row(
                        children: [
                          ShrinkableButton(
                            onTap: showImagePickerModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(
                                  isDark ? 30 : 15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.primary.withAlpha(
                                    isDark ? 50 : 30,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Attach Image',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ShrinkableButton(
                            onTap: toggleVoiceRecording,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isRecordingVoice.value
                                    ? colors.error
                                    : colors.primary
                                        .withAlpha(isDark ? 30 : 15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRecordingVoice.value
                                      ? colors.error
                                      : colors.primary
                                          .withAlpha(isDark ? 50 : 30),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: AppMotion.snappy,
                                    switchInCurve: AppMotion.easeOutCubic,
                                    child: isRecordingVoice.value
                                        ? _LiveAudioWaveVisualizer(
                                            key: const ValueKey('recording_wave'),
                                            color: colors.white,
                                          )
                                        : Icon(
                                            Icons.mic_rounded,
                                            key: const ValueKey('idle_mic'),
                                            size: 16,
                                            color: colors.primary,
                                          ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedSwitcher(
                                    duration: AppMotion.snappy,
                                    switchInCurve: AppMotion.easeOutCubic,
                                    child: Text(
                                      isRecordingVoice.value
                                          ? 'Listening (${voiceNoteDurationSeconds.value}s)...'
                                          : 'Voice Note & STT',
                                      key: ValueKey(
                                        '${isRecordingVoice.value}_${voiceNoteDurationSeconds.value}',
                                      ),
                                      style: typography.caption.bold.copyWith(
                                        color: isRecordingVoice.value
                                            ? colors.white
                                            : colors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Voice note player preview if recorded
                      if (recordedVoiceNoteUrl.value != null) ...[
                        VoiceNotePlayerWidget(
                          audioUrl: recordedVoiceNoteUrl.value!,
                          durationSeconds: voiceNoteDurationSeconds.value > 0
                              ? voiceNoteDurationSeconds.value
                              : null,
                          onDelete: () {
                            recordedVoiceNoteUrl.value = null;
                            voiceNoteDurationSeconds.value = 0;
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Image attachments thumbnails strip
                      if (attachedImages.value.isNotEmpty) ...[
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: attachedImages.value.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, idx) {
                              final path = attachedImages.value[idx];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(path),
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: 84,
                                                height: 84,
                                                color: colors.surfaceSecondary,
                                                child: Icon(
                                                  Icons.image_rounded,
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        attachedImages.value = attachedImages
                                            .value
                                            .where((p) => p != path)
                                            .toList();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.black.withAlpha(160),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 12,
                                          color: colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const SizedBox(height: 14),

                      // Semantic Tags Section (aligned on the same horizontal line with wrapping)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Semantic Tags',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            'Max 5 tags (Optional)',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...tags.value.map(
                              (tag) => Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colors.primary.withAlpha(50),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '#$tag',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        unawaited(HapticFeedback.lightImpact());
                                        tags.value = tags.value
                                            .where((t) => t != tag)
                                            .toList();
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (tags.value.length < 5)
                              if (isAddingTag.value)
                                Container(
                                  width: 110,
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors.surfaceSecondary
                                        : colors.surfaceSecondary.withAlpha(
                                            160,
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: TextField(
                                      controller: tagInputController,
                                      autofocus: true,
                                      style: typography.caption.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 12,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'tag...',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        isDense: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (val) {
                                        final cleaned = val
                                            .replaceAll('#', '')
                                            .trim();
                                        if (cleaned.isNotEmpty &&
                                            !tags.value.contains(cleaned)) {
                                          tags.value = [...tags.value, cleaned];
                                        }
                                        tagInputController.clear();
                                        isAddingTag.value = false;
                                      },
                                    ),
                                  ),
                                )
                              else
                                ShrinkableButton(
                                  onTap: () => isAddingTag.value = true,
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? colors.surfaceSecondary
                                          : colors.surfaceSecondary.withAlpha(
                                              120,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          size: 14,
                                          color: colors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Add tag',
                                          style: typography.caption.medium
                                              .copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // DISCUSSION POLICIES
                      Text(
                        'DISCUSSION POLICIES',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Policy 1: Post Anonymously
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.masks_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Post Anonymously',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Hide your username and avatar from peers in this discussion thread',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: isAnonymous.value,
                              activeColor: colors.primary,
                              onChanged: (val) =>
                                  isAnonymous.value = val ?? false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Policy 2: AI hints in replies
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Educational AI Hints in Replies',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Allow student peers to generate structured AI explanations on this thread',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: allowAiHints.value,
                              activeColor: colors.primary,
                              onChanged: (val) =>
                                  allowAiHints.value = val ?? true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Policy 3: Notify on verified solutions
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 20,
                              color: colors.success,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notify on Verified Solutions',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Receive priority ping when a mentor validates the formula derivation',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: notifyVerifiedSolution.value,
                              activeColor: colors.primary,
                              onChanged: (val) =>
                                  notifyVerifiedSolution.value = val ?? true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Autosave & Character Counter Bar (Sitting directly on the screen)
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      Expanded(
                        child: Text(
                          'Draft saved automatically (${lastSavedTime.value})',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${characterCount.value} characters',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          titleController.clear();
                          contentController.clear();
                          attachedImages.value = [];
                          recordedVoiceNoteUrl.value = null;
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Discard',
                          style: typography.caption.bold.copyWith(
                            color: colors.error,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatActionBtn({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    String? label,
    bool isAccent = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final color = isAccent ? colors.primary : colors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) => AnimatedScale(
          scale: isHovered ? 1.08 : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          child: ShrinkableButton(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isAccent
                    ? color.withAlpha(
                        isDark ? (isHovered ? 55 : 35) : (isHovered ? 35 : 20),
                      )
                    : (isHovered
                          ? colors.primary.withAlpha(isDark ? 25 : 15)
                          : colors.transparent),
                borderRadius: AppRadius.radiusBadge,
              ),
              child: label != null
                  ? Text(
                      label,
                      style: typography.caption.bold.copyWith(
                        color: color,
                        fontSize: 13,
                      ),
                    )
                  : Icon(icon, size: 17, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatDivider(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colors.primary.withAlpha(30),
    );
  }
}

class _LiveAudioWaveVisualizer extends StatefulWidget {
  const _LiveAudioWaveVisualizer({required this.color, super.key});

  final Color color;

  @override
  State<_LiveAudioWaveVisualizer> createState() =>
      _LiveAudioWaveVisualizerState();
}

class _LiveAudioWaveVisualizerState extends State<_LiveAudioWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(4 + val * 8),
            const SizedBox(width: 2),
            _buildBar(12 - val * 7),
            const SizedBox(width: 2),
            _buildBar(6 + val * 6),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(3, 14),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
