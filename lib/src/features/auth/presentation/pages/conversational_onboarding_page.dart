import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/chat_onboarding_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/inline_goal_slider_bubble.dart';
import 'package:kortex/src/features/auth/presentation/widgets/inline_track_picker_bubble.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Single-screen conversational onboarding chat canvas guiding the student via
/// interactive AI dialogue.
class ConversationalOnboardingPage extends HookWidget {
  const ConversationalOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final scrollController = useScrollController();
    final textController = useTextEditingController();

    useEffect(() {
      context.read<ChatOnboardingBloc>().add(const ChatOnboardingStarted());
      return null;
    }, const []);

    return BlocBuilder<ChatOnboardingBloc, ChatOnboardingState>(
      builder: (context, chatState) {
        final onboardingState = context.watch<OnboardingCubit>().state;

        return Column(
          children: [
            // Chat Message Stream
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount:
                    chatState.messages.length + (chatState.isThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == chatState.messages.length) {
                    // Thinking Bubble
                    return _ThinkingIndicatorBubble(isDark: isDark);
                  }

                  final msg = chatState.messages[index];
                  final isAi = msg.sender == ChatSender.ai;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: isAi
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: isAi
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAi) ...[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.primary,
                                      colors.syllabotAccent,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                  color: colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isAi
                                      ? (isDark
                                            ? colors.surfaceSecondary
                                            : colors.surfacePrimary)
                                      : colors.primary,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isAi ? 4 : 18),
                                    bottomRight: Radius.circular(isAi ? 18 : 4),
                                  ),
                                  border: Border.all(
                                    color: isAi
                                        ? colors.primary.withAlpha(
                                            isDark ? 40 : 20,
                                          )
                                        : colors.transparent,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withAlpha(
                                        isDark ? 30 : 10,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg.text,
                                  style: typography.body.regular.copyWith(
                                    color: isAi
                                        ? colors.textPrimary
                                        : colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Embedded Interactive Action Widgets
                        if (msg.embeddedWidgetType != null) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 44),
                            child: _buildEmbeddedWidget(
                              context: context,
                              type: msg.embeddedWidgetType!,
                              onboardingState: onboardingState,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Message Input Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            context.read<ChatOnboardingBloc>().add(
                              ChatOnboardingUserMessageSent(val),
                            );
                            textController.clear();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: l10n.askAiAboutCurriculum,
                          hintStyle: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? colors.surfaceTertiary
                              : colors.surfaceSecondary.withAlpha(80),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ShrinkableButton(
                      onTap: () {
                        final text = textController.text.trim();
                        if (text.isNotEmpty) {
                          context.read<ChatOnboardingBloc>().add(
                            ChatOnboardingUserMessageSent(text),
                          );
                          textController.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmbeddedWidget({
    required BuildContext context,
    required EmbeddedWidgetType type,
    required OnboardingState onboardingState,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    switch (type) {
      case EmbeddedWidgetType.trackPicker:
        return InlineTrackPickerBubble(
          selectedTrack: onboardingState.selectedTrack,
          onTrackSelected: (track) {
            context.read<OnboardingCubit>().selectTrack(track.id);
            context.read<OnboardingCubit>().syncStep(1);
            context.read<ChatOnboardingBloc>().add(
              ChatOnboardingTrackChosen(track.name),
            );
          },
        );

      case EmbeddedWidgetType.goalSlider:
        return InlineGoalSliderBubble(
          initialDailyTarget: onboardingState.dailyTarget,
          initialRetentionBenchmark: onboardingState.retentionBenchmark,
          onGoalConfirmed: (target, retention) {
            context.read<OnboardingCubit>().updateDailyTarget(target);
            context.read<OnboardingCubit>().updateRetentionBenchmark(retention);
            context.read<OnboardingCubit>().syncStep(2);
            context.read<ChatOnboardingBloc>().add(
              ChatOnboardingGoalChosen(
                dailyTarget: target,
                retentionPercent: (retention * 100).round(),
              ),
            );
          },
        );

      case EmbeddedWidgetType.summaryReady:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(220)
                : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 60 : 30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: colors.syllabotAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Curriculum Setup Ready',
                    style: typography.subhead.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Track: ${onboardingState.currentTrackEntity.name}\n'
                'Target: ${onboardingState.dailyTarget} cards/day '
                '(~${(onboardingState.retentionBenchmark * 100).round()}'
                '% retention)',
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ShrinkableButton(
                onTap: onboardingState.isLoading
                    ? null
                    : () {
                        unawaited(
                          context.read<OnboardingCubit>().completeOnboarding(),
                        );
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.primary.withAlpha(220),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: onboardingState.isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.white,
                            ),
                          )
                        : Text(
                            l10n.completeAndGoToDashboard,
                            style: typography.footnote.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _ThinkingIndicatorBubble extends StatelessWidget {
  const _ThinkingIndicatorBubble({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.syllabotAccent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.aiThinking,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
