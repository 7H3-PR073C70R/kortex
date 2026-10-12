import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_history_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Top app bar actions for Syllabot Chat.
class SyllabotChatAppBarActions extends StatelessWidget {
  const SyllabotChatAppBarActions({
    required this.onOpenVoiceDialogue,
    required this.onOpenConvertToDeck,
    this.subscriptionGuard,
    super.key,
  });

  final void Function(BuildContext context, SyllabotChatState state)
      onOpenVoiceDialogue;
  final void Function(BuildContext context, SyllabotChatState state)
      onOpenConvertToDeck;
  final SubscriptionGuard? subscriptionGuard;

  SubscriptionGuard get _guard =>
      subscriptionGuard ??
      (locator.isRegistered<SubscriptionGuard>()
          ? locator<SubscriptionGuard>()
          : SubscriptionGuard());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isPro = _guard.isPro;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Interactive Voice Dialogue Mode Action
        BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
          builder: (context, state) {
            return PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return AnimatedContainer(
                  duration: AppMotion.snappy,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.syllabotAccent.withAlpha(25)
                        : context.colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: IconButton(
                    tooltip: l10n.voiceDialogueModeTooltip,
                    icon: Icon(
                      Icons.graphic_eq_rounded,
                      color: colors.syllabotAccent,
                      size: 22,
                    ),
                    onPressed: () => onOpenVoiceDialogue(context, state),
                  ),
                );
              },
            );
          },
        ),

        // 2. Turn to Flashcard Deck Action
        BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
          builder: (context, state) {
            if (state.isGeneratingDeck) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Tooltip(
                  message: l10n.generatingDeckProgress,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.syllabotAccent,
                      ),
                    ),
                  ),
                ),
              );
            }

            if (state.isConvertedToDeck) {
              return Tooltip(
                message: l10n.deckAlreadyGeneratedFromChat,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: colors.syllabotAccent.withAlpha(160),
                    size: 22,
                  ),
                ),
              );
            }

            return PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return AnimatedContainer(
                  duration: AppMotion.snappy,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.primary.withAlpha(25)
                        : context.colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: l10n.convertToDeckTitle,
                        icon: Icon(
                          Icons.style_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                        onPressed: () => onOpenConvertToDeck(context, state),
                      ),
                      if (!isPro)
                        Positioned(
                          top: 6,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.micro,
                              ),
                            ),
                            child: Text(
                              'PRO',
                              style: typography.caption.bold.copyWith(
                                color: Colors.white,
                                fontSize: 7.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        // 3. Share Insight to Study Circle / Forum Action
        BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
          builder: (context, state) {
            final aiMessages = state.messages
                .where((m) => m.sender == MessageSender.syllabot)
                .toList();
            if (aiMessages.isEmpty) return const SizedBox.shrink();
            return PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return AnimatedContainer(
                  duration: AppMotion.snappy,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.syllabotAccent.withAlpha(25)
                        : context.colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: IconButton(
                    tooltip: l10n.tooltipShareInsight,
                    icon: Icon(
                      Icons.share_outlined,
                      color: colors.syllabotAccent,
                      size: 21,
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      final lastAiText = aiMessages.last.text;
                      unawaited(
                        CreatePostBottomSheet.show(
                          context,
                          onSubmit:
                              ({
                                required title,
                                required content,
                                required track,
                                latexContent,
                                isQuestion = false,
                                syllabusTag = 'AI Insights',
                                isAnonymous = false,
                              }) {
                                if (locator.isRegistered<CommunityHubBloc>()) {
                                  locator<CommunityHubBloc>().add(
                                    CreateForumPostEvent(
                                      title: title,
                                      content: content.isNotEmpty
                                          ? content
                                          : lastAiText,
                                      track: track,
                                      latexContent: latexContent,
                                      isQuestion: isQuestion,
                                      syllabusTag: syllabusTag,
                                      isAnonymous: isAnonymous,
                                    ),
                                  );
                                }
                                context.showSnackBar(
                                  message:
                                      'Shared insight with your cohort! 💡',
                                  type: SnackBarType.success,
                                );
                              },
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),

        // 4. Conversation History Browser Action
        BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
          builder: (context, state) {
            return PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return AnimatedContainer(
                  duration: AppMotion.snappy,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.surfaceSecondary
                        : context.colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: IconButton(
                    tooltip: l10n.tooltipChatHistory,
                    icon: Icon(
                      Icons.history_rounded,
                      color: colors.textPrimary,
                      size: 23,
                    ),
                    onPressed: () {
                      unawaited(
                        SyllabotHistorySheet.show(
                          context,
                          currentSessionId: state.sessionId,
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),

        // 5. New Chat Session Action
        BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
          builder: (context, state) {
            return PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return AnimatedContainer(
                  duration: AppMotion.snappy,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.surfaceSecondary
                        : context.colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: IconButton(
                    tooltip: l10n.newConversationTooltip,
                    icon: Icon(
                      Icons.add_comment_outlined,
                      color: colors.textSecondary,
                      size: 21,
                    ),
                    onPressed: state.isGeneratingDeck
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            context.read<SyllabotChatBloc>().add(
                              const StartNewSessionEvent(),
                            );
                          },
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
