import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/syllabot/data/models/prompt_suggestion_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/audio_input_waveform_button.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/convert_to_deck_action_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/engine_status_indicator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/socratic_mode_selector.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/streaming_text_typing_indicator.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class SyllabotChatPage extends StatelessWidget {
  const SyllabotChatPage({this.initialPrompt, super.key});

  final String? initialPrompt;

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
      child: _SyllabotChatView(initialPrompt: initialPrompt),
    );
  }
}

class _SyllabotChatView extends HookWidget {
  const _SyllabotChatView({this.initialPrompt});

  final String? initialPrompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final hasInput = useState<bool>(false);

    useEffect(() {
      void listener() {
        hasInput.value = textController.text.trim().isNotEmpty;
      }

      textController.addListener(listener);
      return () => textController.removeListener(listener);
    }, [textController]);

    return AuraMeshNebula(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Center(child: SyllabotAvatar(size: 34)),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.syllabotTitle,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                  buildWhen: (p, c) => p.engineType != c.engineType,
                  builder: (context, state) {
                    return EngineStatusIndicator(
                      engineType: state.engineType,
                      onToggleEngine: (newEngine) {
                        context.read<SyllabotChatBloc>().add(
                              ChangeEngineTypeEvent(newEngine),
                            );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            // Convert to Flashcard Deck Button
            BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
              builder: (context, state) {
                if (state.messages.isEmpty) return const SizedBox.shrink();

                return IconButton(
                  tooltip: l10n.convertToDeckTitle,
                  icon: Icon(
                    Icons.style_rounded,
                    color: colors.syllabotAccent,
                  ),
                  onPressed: () {
                    unawaited(
                      ConvertToDeckActionSheet.show(
                        context,
                        onGenerateDeck: (title, courseCode) {
                          context.read<SyllabotChatBloc>().add(
                                ConvertToDeckEvent(
                                  sessionId: state.sessionId,
                                  deckTitle: title,
                                  courseCode: courseCode,
                                ),
                              );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            // New Session Action
            IconButton(
              tooltip: l10n.newChatSession,
              icon: Icon(
                Icons.add_comment_outlined,
                color: colors.textPrimary,
              ),
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                context
                    .read<SyllabotChatBloc>()
                    .add(const StartNewSessionEvent());
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocConsumer<SyllabotChatBloc, SyllabotChatState>(
          listener: (context, state) {
            if (state.status == SyllabotStatus.deckGenerated) {
              context.showSnackBar(
                message: l10n.convertToDeckSuccess,
              );
              // Trigger DecksBloc to reload if registered
              if (locator.isRegistered<DecksBloc>()) {
                locator<DecksBloc>().add(const DecksRefreshed());
              }
            }

            // Auto-scroll on new messages or streaming tokens
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                unawaited(
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                  ),
                );
              }
            });
          },
          builder: (context, state) {
            return Column(
              children: [
                const SizedBox(height: 8),

                // Socratic Mode Selector Pills
                SocraticModeSelector(
                  selectedMode: state.socraticMode,
                  onModeSelected: (mode) {
                    context.read<SyllabotChatBloc>().add(
                          ChangeSocraticModeEvent(mode),
                        );
                  },
                ),
                const SizedBox(height: 8),

                // Chat Messages Feed / Empty State
                Expanded(
                  child: state.messages.isEmpty && !state.isStreaming
                      ? _EmptyChatSuggestionsView(
                          onSelectPrompt: (prompt) {
                            final sid = state.sessionId.isNotEmpty
                                ? state.sessionId
                                : 'session_'
                                    '${DateTime.now().millisecondsSinceEpoch}';
                            context.read<SyllabotChatBloc>().add(
                                  SubmitPromptEvent(
                                    prompt: prompt,
                                    sessionId: sid,
                                    socraticMode: state.socraticMode,
                                    engineType: state.engineType,
                                  ),
                                );
                          },
                        )
                      : ListView.builder(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.only(
                            top: 12,
                            bottom: 24,
                            left: 4,
                            right: 4,
                          ),
                          itemCount: state.messages.length +
                              (state.isStreaming ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < state.messages.length) {
                              final msg = state.messages[index];
                              return ChatBubbleWidget(
                                message: msg,
                                onRetry: () {
                                  context.read<SyllabotChatBloc>().add(
                                        const RetryLastMessageEvent(),
                                      );
                                },
                              );
                            }

                            // Streaming bubble in-flight
                            return ChatBubbleWidget(
                              message: ChatMessageEntity(
                                id: 'streaming_temp',
                                sessionId: state.sessionId,
                                sender: MessageSender.syllabot,
                                text: state.streamingText.isNotEmpty
                                    ? state.streamingText
                                    : 'Thinking and analyzing your question...',
                                timestamp: DateTime.now(),
                                engineType: state.engineType,
                                isStreaming: true,
                              ),
                            );
                          },
                        ),
                ),

                // Typing Indicator
                if (state.isStreaming && state.streamingText.isEmpty)
                  const StreamingTextTypingIndicator(),

                // Bottom Floating Glassmorphic Input Dock
                _BottomChatInputDock(
                  controller: textController,
                  hasInput: hasInput.value,
                  isStreaming: state.isStreaming,
                  onSubmit: () {
                    final text = textController.text.trim();
                    if (text.isEmpty) return;

                    unawaited(HapticFeedback.lightImpact());
                    textController.clear();

                    final sid = state.sessionId.isNotEmpty
                        ? state.sessionId
                        : 'session_'
                            '${DateTime.now().millisecondsSinceEpoch}';

                    context.read<SyllabotChatBloc>().add(
                          SubmitPromptEvent(
                            prompt: text,
                            sessionId: sid,
                            socraticMode: state.socraticMode,
                            engineType: state.engineType,
                            contextHistory: state.messages,
                          ),
                        );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyChatSuggestionsView extends StatelessWidget {
  const _EmptyChatSuggestionsView({required this.onSelectPrompt});

  final ValueChanged<String> onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final suggestions = PromptSuggestionModel.defaults;

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
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your 24/7 AI tutor for STEM derivations, exam prep,'
              ' and flashcard synthesis.',
              textAlign: TextAlign.center,
              style: typography.subhead.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            // Suggestions List
            ...suggestions.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    onSelectPrompt(s.text);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(140)
                          : colors.surfacePrimary.withAlpha(180),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 50 : 30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          s.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.text,
                            style: typography.footnote.medium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: colors.textSecondary,
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
}

class _BottomChatInputDock extends StatelessWidget {
  const _BottomChatInputDock({
    required this.controller,
    required this.hasInput,
    required this.isStreaming,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool hasInput;
  final bool isStreaming;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(220)
              : colors.surfacePrimary.withAlpha(240),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 70 : 40),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withAlpha(isDark ? 50 : 20),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Audio Waveform Recorder
            AudioInputWaveformButton(
              onTranscriptionResult: (transcript) {
                controller.text = transcript;
              },
            ),
            const SizedBox(width: 10),

            // Text Input Field
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                style: typography.body.medium.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.inputFieldPlaceholder,
                  hintStyle: typography.subhead.regular.copyWith(
                    color: colors.textSecondary.withAlpha(140),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Submit Button
            ShrinkableButton(
              onTap: (hasInput && !isStreaming) ? onSubmit : null,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: (hasInput && !isStreaming)
                        ? [
                            colors.primary,
                            colors.primary.withAlpha(200),
                          ]
                        : [
                            colors.textSecondary.withAlpha(60),
                            colors.textSecondary.withAlpha(40),
                          ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: (hasInput && !isStreaming)
                        ? Colors.white
                        : colors.textSecondary.withAlpha(120),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
