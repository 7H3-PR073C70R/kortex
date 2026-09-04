import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';
import 'package:kortex/src/shared/widgets/typewriter_text.dart';

enum _ContentChatSender { syllabot, user }

class _ContentChatMessage {
  const _ContentChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.isCard = false,
    this.items = const [],
  });

  final String id;
  final _ContentChatSender sender;
  final String text;
  final bool isCard;
  final List<RecommendedContentItem> items;
}

/// Conversational content recommendations view with Syllabot AI.
///
/// Features animated "Thinking..." state and live typewriter streaming.
class ContentChatView extends HookWidget {
  const ContentChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final cubit = context.watch<ContentRecommendationCubit>();
    final contentState = cubit.state;

    final scrollController = useScrollController();
    final isThinking = useState<bool>(false);
    final thinkingLabel = useState<String>('Thinking...');
    final isTyping = useState<bool>(false);
    final latestBotMsgId = useState<String>('');
    final hasResponded = useState<bool>(false);

    final messages = useState<List<_ContentChatMessage>>([
      const _ContentChatMessage(
        id: 'msg_welcome',
        sender: _ContentChatSender.syllabot,
        text:
            'I have analyzed your academic calibration and pre-populated your '
            'workspace with verified high-yield study resources!',
      ),
      if (contentState.items.isNotEmpty)
        _ContentChatMessage(
          id: 'msg_items',
          sender: _ContentChatSender.syllabot,
          text: 'Here is what we have prepared for you:',
          isCard: true,
          items: contentState.items,
        ),
      const _ContentChatMessage(
        id: 'msg_prompt',
        sender: _ContentChatSender.syllabot,
        text:
            'Would you like to start studying with these pre-loaded materials '
            'or configure custom uploads later?',
      ),
    ]);

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          unawaited(
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutQuad,
            ),
          );
        }
      });
    }

    void handleOptionSelected(String label) {
      unawaited(HapticFeedback.lightImpact());
      hasResponded.value = true;

      final userMsg = _ContentChatMessage(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        sender: _ContentChatSender.user,
        text: label,
      );
      messages.value = [...messages.value, userMsg];
      scrollToBottom();

      isThinking.value = true;
      thinkingLabel.value = 'Configuring spaced repetition schedule...';

      Timer(const Duration(milliseconds: 950), () {
        if (!context.mounted) return;
        isThinking.value = false;

        final msgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
        final botMsg = _ContentChatMessage(
          id: msgId,
          sender: _ContentChatSender.syllabot,
          text:
              'Materials calibrated! '
              'Let us now configure your study preferences.',
        );
        messages.value = [...messages.value, botMsg];
        latestBotMsgId.value = msgId;
        isTyping.value = true;
        scrollToBottom();

        Timer(const Duration(milliseconds: 1200), () {
          if (context.mounted) {
            unawaited(context.router.replaceAll([const PermissionsRoute()]));
          }
        });
      });
    }

    final isInputNeeded =
        !hasResponded.value && !isThinking.value && !isTyping.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                // 1. Chat Message Thread
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount:
                        messages.value.length + (isThinking.value ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.value.length) {
                        return _ThinkingBubble(
                          statusText: thinkingLabel.value,
                        );
                      }

                      final msg = messages.value[index];
                      final isBot = msg.sender == _ContentChatSender.syllabot;
                      final isStreaming =
                          isBot &&
                          msg.id == latestBotMsgId.value &&
                          isTyping.value;

                      if (!isBot) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(18),
                                    bottomRight: Radius.circular(4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withAlpha(50),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg.text,
                                  style: typography.callout.regular.copyWith(
                                    color: colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SyllabotAvatar(size: 36),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? colors.surfaceSecondary.withAlpha(
                                              160,
                                            )
                                          : colors.surfacePrimary,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(18),
                                      ),
                                      border: Border.all(
                                        color: isDark
                                            ? colors.surfaceBorderHighlight
                                                  .withAlpha(70)
                                            : colors.surfaceBorder,
                                      ),
                                    ),
                                    child: isStreaming
                                        ? TypewriterText(
                                            text: msg.text,
                                            onTick: scrollToBottom,
                                            onComplete: () {
                                              isTyping.value = false;
                                              scrollToBottom();
                                            },
                                            style: typography.callout.regular
                                                .copyWith(
                                                  color: colors.textPrimary,
                                                  fontSize: 14,
                                                  height: 1.35,
                                                ),
                                          )
                                        : Text(
                                            msg.text,
                                            style: typography.callout.regular
                                                .copyWith(
                                                  color: colors.textPrimary,
                                                  fontSize: 14,
                                                  height: 1.35,
                                                ),
                                          ),
                                  ),
                                  if (msg.isCard && msg.items.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...msg.items.map((item) {
                                      final taglineStyle = typography
                                          .footnote
                                          .semiBold
                                          .copyWith(color: colors.textPrimary);
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? colors.surfaceSecondary
                                                    .withAlpha(120)
                                              : colors.surfacePrimary,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: colors.primary.withAlpha(50),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: colors.primary.withAlpha(
                                                  25,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.auto_stories_rounded,
                                                color: colors.primary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          item.tagline,
                                                          style: taglineStyle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      AppBadge(
                                                        label: item.badge,
                                                        variant: AppBadgeVariant
                                                            .syllabot,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.description,
                                                    style: typography
                                                        .caption
                                                        .regular
                                                        .copyWith(
                                                          color: colors
                                                              .textSecondary,
                                                          fontSize: 11.5,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 2. Context-Driven Quick Choice Chips
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: !isInputNeeded
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(120)
                                : colors.surfacePrimary,
                            border: Border(
                              top: BorderSide(
                                color: colors.surfaceBorder.withAlpha(
                                  isDark ? 60 : 40,
                                ),
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _ContentQuickChip(
                                  icon: Icons.rocket_launch_rounded,
                                  label: l10n.contentGetStartedButton,
                                  onTap: () => handleOptionSelected(
                                    l10n.contentGetStartedButton,
                                  ),
                                ),
                                _ContentQuickChip(
                                  icon: Icons.upload_file_rounded,
                                  label: 'Upload Custom Syllabus',
                                  onTap: () => handleOptionSelected(
                                    'Upload Custom Syllabus',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThinkingBubble extends HookWidget {
  const _ThinkingBubble({
    required this.statusText,
  });

  final String statusText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(
      () {
        unawaited(controller.repeat());
        return null;
      },
      const [],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SyllabotAvatar(size: 36),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(160)
                  : colors.surfacePrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(70)
                    : colors.surfaceBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      final delay = i * 0.2;
                      final t = (controller.value - delay) % 1.0;
                      final curveValue = math.sin(t * math.pi);
                      final scale =
                          0.6 + (0.4 * (curveValue > 0 ? curveValue : 0));
                      final opacity =
                          0.4 + (0.6 * (curveValue > 0 ? curveValue : 0));

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.2, 1.0),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 1
                                  ? colors.syllabotAccent
                                  : colors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(width: 10),
                Text(
                  statusText,
                  style: typography.footnote.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
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

class _ContentQuickChip extends StatelessWidget {
  const _ContentQuickChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: 'Quick action: $label',
        child: ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(140)
                  : colors.surfacePrimary,
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(70)
                    : colors.surfaceBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: typography.callout.semiBold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
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
