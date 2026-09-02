import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/data/models/prompt_suggestion_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/convert_to_deck_action_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/local_llm_download_bar.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/streaming_text_typing_indicator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_chat_input_bar.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue_modal.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class SyllabotChatPage extends StatelessWidget {
  const SyllabotChatPage({
    this.initialPrompt,
    this.onCollapse,
    super.key,
  });

  final String? initialPrompt;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SyllabotChatBloc>(
      create: (_) {
        final bloc = locator<SyllabotChatBloc>();
        if (initialPrompt != null && initialPrompt!.trim().isNotEmpty) {
          final sid = 'session_${DateTime.now().millisecondsSinceEpoch}';
          bloc.add(
            SubmitPromptEvent(
              prompt: initialPrompt!.trim(),
              sessionId: sid,
              socraticMode: SocraticMode.stepByStep,
              engineType: ExecutionEngineType.cloudSupabase,
            ),
          );
        }
        return bloc;
      },
      child: _SyllabotChatView(
        initialPrompt: initialPrompt,
        onCollapse: onCollapse,
      ),
    );
  }
}

class _SyllabotChatView extends HookWidget {
  const _SyllabotChatView({
    this.initialPrompt,
    this.onCollapse,
  });

  final String? initialPrompt;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final ttsHandler = useMemoized(TextToSpeechHandler.new);

    final calibrationProfileState = useState<CalibrationProfile?>(null);
    final isDownloadingModel = useState<bool>(false);
    final downloadProgress = useState<double>(0);
    final downloadSubscription = useRef<StreamSubscription<double>?>(null);

    useEffect(
      () {
        unawaited(
          locator<CalibrationRepository>()
              .getCalibrationProfile()
              .then((result) {
            result.fold(
              (_) {},
              (profile) {
                calibrationProfileState.value = profile;
              },
            );
          }),
        );
        return () {
          if (downloadSubscription.value != null) {
            unawaited(downloadSubscription.value!.cancel());
          }
          ttsHandler.dispose();
        };
      },
      [ttsHandler],
    );

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          unawaited(
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      });
    }

    void handleEngineSwitch(
      BuildContext pageContext,
      ExecutionEngineType targetEngine,
    ) {
      if (targetEngine == ExecutionEngineType.cloudSupabase) {
        pageContext.read<SyllabotChatBloc>().add(
              const ChangeEngineTypeEvent(ExecutionEngineType.cloudSupabase),
            );
        pageContext.showSnackBar(
          message: l10n.engineCloudSupabase,
        );
        return;
      }

      // Switching to Local On-Device LLM
      final localLlm = locator<LocalLlmEngineClient>();
      if (localLlm.isModelDownloaded) {
        pageContext.read<SyllabotChatBloc>().add(
              const ChangeEngineTypeEvent(ExecutionEngineType.localOnDevice),
            );
        pageContext.showSnackBar(
          message: l10n.engineLocalOnDevice,
          type: SnackBarType.success,
        );
      } else {
        // Start downloading model weights and replace bottom bar
        isDownloadingModel.value = true;
        downloadProgress.value = 0.05;

        downloadSubscription.value = localLlm.downloadModel().listen(
          (progress) {
            downloadProgress.value = progress;
          },
          onDone: () {
            isDownloadingModel.value = false;
            if (pageContext.mounted) {
              pageContext.read<SyllabotChatBloc>().add(
                    const ChangeEngineTypeEvent(
                      ExecutionEngineType.localOnDevice,
                    ),
                  );
              pageContext.showSnackBar(
                message: 'On-Device Neural Engine ready! Activated.',
                type: SnackBarType.success,
              );
            }
          },
          onError: (_) {
            isDownloadingModel.value = false;
            if (pageContext.mounted) {
              pageContext.showSnackBar(
                message: 'Download failed. Check connection.',
                type: SnackBarType.error,
              );
            }
          },
        );
      }
    }

    void cancelModelDownload(BuildContext pageContext) {
      if (downloadSubscription.value != null) {
        unawaited(downloadSubscription.value!.cancel());
      }
      isDownloadingModel.value = false;
      pageContext.showSnackBar(
        message: 'On-Device Engine download cancelled.',
      );
    }

    void openVoiceDialogue(
      BuildContext dialogContext,
      SyllabotChatState state,
    ) {
      unawaited(
        VoiceDialogueModal.show(
          context: dialogContext,
          ttsHandler: ttsHandler,
          initialMode: state.socraticMode,
          onSendPrompt: (voicePrompt) async {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final sid = state.sessionId.isNotEmpty
                ? state.sessionId
                : 'session_$nowMs';

            dialogContext.read<SyllabotChatBloc>().add(
                  SubmitPromptEvent(
                    prompt: voicePrompt,
                    sessionId: sid,
                    socraticMode: state.socraticMode,
                    engineType: state.engineType,
                  ),
                );

            // Dynamic response synthesis
            final localLlm = locator<LocalLlmEngineClient>();
            final stream = localLlm.generate(
              prompt: voicePrompt,
              systemInstruction: '',
              socraticMode: state.socraticMode,
            );
            final buffer = StringBuffer();
            await stream.forEach(buffer.write);
            return buffer.toString();
          },
        ),
      );
    }

    void openConvertToDeck(BuildContext sheetContext, SyllabotChatState state) {
      if (state.messages.isEmpty) {
        sheetContext.showSnackBar(
          message: 'Start a conversation with Syllabot to generate cards',
        );
        return;
      }

      unawaited(
        ConvertToDeckActionSheet.show(
          sheetContext,
          onGenerateDeck: (title, courseCode) {
            sheetContext.read<SyllabotChatBloc>().add(
                  ConvertToDeckEvent(
                    sessionId: state.sessionId,
                    deckTitle: title,
                    courseCode: courseCode,
                  ),
                );
          },
        ),
      );
    }

    return BlocListener<SyllabotChatBloc, SyllabotChatState>(
      listener: (context, state) {
        if (state.status == SyllabotStatus.streaming) {
          scrollToBottom();
        }

        if (state.generatedDeck != null) {
          final deck = state.generatedDeck!;
          locator<DecksBloc>().add(const DecksRefreshed());
          context.showSnackBar(
            message: l10n.deckCreatedFromSyllabot(
              deck.title,
              deck.totalCards,
            ),
            type: SnackBarType.success,
          );
        }

        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              onCollapse != null
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary,
              size: onCollapse != null ? 28 : 20,
            ),
            tooltip: onCollapse != null
                ? l10n.minimizeChatTooltip
                : l10n.backButton,
            onPressed: () {
              if (onCollapse != null) {
                onCollapse!();
              } else {
                unawaited(context.router.maybePop());
              }
            },
          ),
          titleSpacing: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SyllabotAvatar(size: 32),
              const SizedBox(width: 10),
              Text(
                l10n.syllabotTitle,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          actions: [
            // 1. Interactive Voice Dialogue Mode Action
            BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
              builder: (context, state) {
                return IconButton(
                  tooltip: l10n.voiceDialogueModeTooltip,
                  icon: Icon(
                    Icons.graphic_eq_rounded,
                    color: colors.syllabotAccent,
                    size: 22,
                  ),
                  onPressed: () => openVoiceDialogue(context, state),
                );
              },
            ),

            // 2. Turn to Flashcard Deck Action
            BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
              builder: (context, state) {
                return IconButton(
                  tooltip: l10n.convertToDeckTitle,
                  icon: Icon(
                    Icons.style_rounded,
                    color: colors.primary,
                    size: 22,
                  ),
                  onPressed: () => openConvertToDeck(context, state),
                );
              },
            ),

            // 3. New Chat Session Action
            IconButton(
              tooltip: l10n.newConversationTooltip,
              icon: Icon(
                Icons.add_comment_outlined,
                color: colors.textSecondary,
                size: 21,
              ),
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                context.read<SyllabotChatBloc>().add(
                      const StartNewSessionEvent(),
                    );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Main Chat Area (Empty Syllabot Greeting or Message Stream)
              Expanded(
                child: BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                  builder: (context, state) {
                    if (state.messages.isEmpty &&
                        state.streamingText.isEmpty &&
                        state.status != SyllabotStatus.streaming) {
                      return _buildEmptySyllabotGreeting(
                        context,
                        colors,
                        typography,
                        l10n,
                        textController,
                        calibrationProfileState.value,
                      );
                    }

                    return _buildMessageListView(
                      context,
                      state,
                      colors,
                      typography,
                      scrollController,
                      ttsHandler,
                    );
                  },
                ),
              ),

              // 2. Actionable Error Banner with 1-Tap Prompt Retry & Offline
              // Switch
              BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                buildWhen: (p, c) =>
                    p.status != c.status || p.errorMessage != c.errorMessage,
                builder: (context, state) {
                  if (state.status != SyllabotStatus.error &&
                      (state.errorMessage == null ||
                          state.errorMessage!.isEmpty)) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.error.withAlpha(isDark ? 35 : 20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.error.withAlpha(isDark ? 90 : 70),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: colors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.errorMessage ??
                                    'Network error. Connect to network or '
                                        'switch to Offline On-Device LLM.',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 1-Tap Switch to Offline LLM
                            if (state.engineType ==
                                ExecutionEngineType.cloudSupabase)
                              ShrinkableButton(
                                onTap: () => handleEngineSwitch(
                                  context,
                                  ExecutionEngineType.localOnDevice,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          colors.surfaceBorder.withAlpha(120),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '🟠',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Use Offline LLM',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // 1-Tap Retry Button
                            if (state.lastPrompt != null)
                              ShrinkableButton(
                                onTap: () {
                                  unawaited(HapticFeedback.mediumImpact());
                                  context.read<SyllabotChatBloc>().add(
                                        const RetryLastMessageEvent(),
                                      );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.error,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.retryAction,
                                        style: typography.caption.bold.copyWith(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 3. Syllabot Chat Bottom Bar (Download Progress vs Input Bar)
              BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                builder: (context, state) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: isDownloadingModel.value
                        ? LocalLlmDownloadBar(
                            progress: downloadProgress.value,
                            onCancel: () => cancelModelDownload(context),
                            currentEngine: state.engineType,
                          )
                        : SyllabotChatInputBar(
                            controller: textController,
                            socraticMode: state.socraticMode,
                            engineType: state.engineType,
                            isLoading: state.status == SyllabotStatus.streaming,
                            onVoiceDialogueTap: () =>
                                openVoiceDialogue(context, state),
                            onModeChanged: (mode) {
                              context.read<SyllabotChatBloc>().add(
                                    ChangeSocraticModeEvent(mode),
                                  );
                            },
                            onEngineChanged: (engine) =>
                                handleEngineSwitch(context, engine),
                            onSubmit: (prompt) {
                              final nowMs =
                                  DateTime.now().millisecondsSinceEpoch;
                              final sid = state.sessionId.isNotEmpty
                                  ? state.sessionId
                                  : 'session_$nowMs';

                              context.read<SyllabotChatBloc>().add(
                                    SubmitPromptEvent(
                                      prompt: prompt,
                                      sessionId: sid,
                                      socraticMode: state.socraticMode,
                                      engineType: state.engineType,
                                    ),
                                  );
                            },
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty Syllabot Greeting & Tailored Academic Suggestions
  Widget _buildEmptySyllabotGreeting(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    TextEditingController textController,
    CalibrationProfile? profile,
  ) {
    final suggestions = PromptSuggestionModel.forProfile(profile);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SyllabotAvatar(size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.syllabotTitle,
              style: typography.headline.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.syllabotEmptySubtitle,
              textAlign: TextAlign.center,
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 24),

            // Tailored Suggestion Cards
            ...suggestions.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ShrinkableButton(
                  onTap: () {
                    textController
                      ..text = s.text
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: s.text.length),
                      );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(90),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(s.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.text,
                                style: typography.body.medium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.category,
                                style: typography.caption.medium.copyWith(
                                  color: colors.primary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: colors.textSecondary.withAlpha(120),
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Active Message Stream List View
  Widget _buildMessageListView(
    BuildContext context,
    SyllabotChatState state,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    ScrollController scrollController,
    TextToSpeechHandler ttsHandler,
  ) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: state.messages.length +
          (state.status == SyllabotStatus.streaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < state.messages.length) {
          final message = state.messages[index];
          return ChatBubbleWidget(
            message: message,
            ttsHandler: ttsHandler,
            onRetry: message.sender == MessageSender.syllabot
                ? () {
                    context.read<SyllabotChatBloc>().add(
                          const RetryLastMessageEvent(),
                        );
                  }
                : null,
          );
        }

        // Live typing typewriter stream indicator
        return const StreamingTextTypingIndicator();
      },
    );
  }
}
