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
import 'package:kortex/src/features/syllabot/data/models/prompt_suggestion_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/convert_to_deck_action_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/engine_status_indicator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/gemini_chat_input_bar.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/streaming_text_typing_indicator.dart';
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

    return BlocListener<SyllabotChatBloc, SyllabotChatState>(
      listener: (context, state) {
        if (state.status == SyllabotStatus.streaming) {
          scrollToBottom();
        }

        if (state.generatedDeck != null) {
          final deck = state.generatedDeck!;
          locator<DecksBloc>().add(const DecksRefreshed());
          context.showSnackBar(
            message: 'Flashcard Deck "${deck.title}" created with '
                '${deck.totalCards} cards!',
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
            ),
            tooltip: onCollapse != null ? 'Minimize Chat' : 'Back',
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
            children: [
              const SyllabotAvatar(size: 32),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.syllabotTitle,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
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
            ],
          ),
          actions: [
            // 1. New Chat Session Action
            IconButton(
              tooltip: 'New Conversation',
              icon: Icon(
                Icons.add_comment_outlined,
                color: colors.textSecondary,
                size: 22,
              ),
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                context.read<SyllabotChatBloc>().add(
                      const StartNewSessionEvent(),
                    );
              },
            ),

            // 2. Convert to Flashcard Deck Action
            BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
              builder: (context, state) {
                if (state.messages.isEmpty) return const SizedBox.shrink();

                return IconButton(
                  tooltip: l10n.convertToDeckTitle,
                  icon: Icon(
                    Icons.style_rounded,
                    color: colors.syllabotAccent,
                    size: 22,
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
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Main Chat Area (Empty Gemini Greeting or Message Stream)
              Expanded(
                child: BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                  builder: (context, state) {
                    if (state.messages.isEmpty &&
                        state.streamingText.isEmpty &&
                        state.status != SyllabotStatus.streaming) {
                      return _buildEmptyGeminiGreeting(
                        context,
                        colors,
                        typography,
                        l10n,
                        textController,
                      );
                    }

                    return _buildMessageListView(
                      context,
                      state,
                      colors,
                      typography,
                      scrollController,
                    );
                  },
                ),
              ),

              // 2. Inline Error Banner with 1-Tap Prompt Retry
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
                      horizontal: 16,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error.withAlpha(isDark ? 35 : 20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.error.withAlpha(isDark ? 90 : 70),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: colors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.errorMessage ??
                                'Unable to generate response. '
                                    'Check connection.',
                            style: typography.caption.medium.copyWith(
                              color: colors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
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
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Retry',
                                style: typography.caption.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // 3. Gemini-Style Unified Input Pill Bar
              BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                builder: (context, state) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: GeminiChatInputBar(
                      controller: textController,
                      socraticMode: state.socraticMode,
                      isLoading: state.status == SyllabotStatus.streaming,
                      onModeChanged: (mode) {
                        context.read<SyllabotChatBloc>().add(
                              ChangeSocraticModeEvent(mode),
                            );
                      },
                      onSubmit: (prompt) {
                        final nowMs = DateTime.now().millisecondsSinceEpoch;
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

  /// Empty Gemini Greeting & Academic Suggestion Cards
  Widget _buildEmptyGeminiGreeting(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    TextEditingController textController,
  ) {
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
              style: typography.headline.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your 24/7 AI tutor for STEM derivations, exam prep, and flashcards',
              textAlign: TextAlign.center,
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 24),

            // Prompt Suggestion Pills
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
                          child: Text(
                            s.text,
                            style: typography.body.medium.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
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
