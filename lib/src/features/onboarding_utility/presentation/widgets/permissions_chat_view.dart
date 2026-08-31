import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/permissions_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';
import 'package:kortex/src/shared/widgets/typewriter_text.dart';

enum _PermChatSender { syllabot, user }

class _PermChatMessage {
  const _PermChatMessage({
    required this.id,
    required this.sender,
    required this.text,
  });

  final String id;
  final _PermChatSender sender;
  final String text;
}

enum _PermChatStep {
  notifications,
  storage,
  completing,
}

/// Conversational permissions view with Syllabot AI.
///
/// Features animated "Thinking..." state and typewriter streaming.
class PermissionsChatView extends HookWidget {
  const PermissionsChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final cubit = context.read<PermissionsCubit>();

    final scrollController = useScrollController();
    final isThinking = useState<bool>(false);
    final thinkingLabel = useState<String>('Thinking...');
    final isTyping = useState<bool>(false);
    final latestBotMsgId = useState<String>('');
    final currentStep = useState<_PermChatStep>(_PermChatStep.notifications);

    final messages = useState<List<_PermChatMessage>>([
      const _PermChatMessage(
        id: 'msg_welcome',
        sender: _PermChatSender.syllabot,
        text:
            'Almost ready! Let us configure two quick preferences so Syllabot '
            'can optimize your study experience.',
      ),
      const _PermChatMessage(
        id: 'msg_notif',
        sender: _PermChatSender.syllabot,
        text:
            'To help you maintain your daily active recall streak and spaced '
            'repetition reviews, may I send you study reminder notifications?',
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

    Future<void> handleNotificationChoice({required bool allow}) async {
      unawaited(HapticFeedback.lightImpact());

      final userMsg = _PermChatMessage(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        sender: _PermChatSender.user,
        text: allow ? 'Allow Notifications' : 'Skip for Now',
      );
      messages.value = [...messages.value, userMsg];
      scrollToBottom();

      if (allow) {
        await cubit.requestNotificationPermission();
      }

      isThinking.value = true;
      thinkingLabel.value = 'Configuring notifications...';
      scrollToBottom();

      Timer(const Duration(milliseconds: 950), () {
        if (!context.mounted) return;
        isThinking.value = false;
        currentStep.value = _PermChatStep.storage;

        final msgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
        final botMsg = _PermChatMessage(
          id: msgId,
          sender: _PermChatSender.syllabot,
          text:
              'Got it! To let you snap textbook diagrams for OCR '
              'scanning and AI syllabus indexing, can Syllabot access '
              'your Camera & Storage?',
        );
        messages.value = [...messages.value, botMsg];
        latestBotMsgId.value = msgId;
        isTyping.value = true;
        scrollToBottom();
      });
    }

    Future<void> handleStorageChoice({required bool allow}) async {
      unawaited(HapticFeedback.lightImpact());

      final userMsg = _PermChatMessage(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        sender: _PermChatSender.user,
        text: allow ? 'Allow Camera & Storage' : 'Skip for Now',
      );
      messages.value = [...messages.value, userMsg];
      scrollToBottom();

      if (allow) {
        await cubit.requestStoragePermission();
      }

      isThinking.value = true;
      thinkingLabel.value = 'Finalizing your workspace...';
      currentStep.value = _PermChatStep.completing;
      scrollToBottom();

      Timer(const Duration(milliseconds: 950), () {
        if (!context.mounted) return;
        isThinking.value = false;

        final msgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
        final botMsg = _PermChatMessage(
          id: msgId,
          sender: _PermChatSender.syllabot,
          text:
              'Workspace calibrated and ready! '
              'Launching your Kortexify dashboard...',
        );
        messages.value = [...messages.value, botMsg];
        latestBotMsgId.value = msgId;
        isTyping.value = true;
        scrollToBottom();

        cubit.finishPermissions();

        Timer(const Duration(milliseconds: 1400), () {
          if (context.mounted) {
            unawaited(
              // ignore: deprecated_member_use, backward-compatible a11y announcement
              SemanticsService.announce(
                l10n.permissionsCompleteAnnouncement,
                TextDirection.ltr,
              ),
            );
            unawaited(context.router.replaceAll([const MainRoute()]));
          }
        });
      });
    }

    final isInputNeeded =
        !isThinking.value &&
        !isTyping.value &&
        currentStep.value != _PermChatStep.completing;

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
                      final isBot = msg.sender == _PermChatSender.syllabot;
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
                                    color: Colors.white,
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
                              child: Container(
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
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 2. Interactive Choice Chips (Only after typing finishes)
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
                                if (currentStep.value ==
                                    _PermChatStep.notifications) ...[
                                  _PermQuickChip(
                                    icon: Icons.notifications_active_rounded,
                                    label: 'Allow Notifications',
                                    onTap: () => handleNotificationChoice(
                                      allow: true,
                                    ),
                                  ),
                                  _PermQuickChip(
                                    icon: Icons.notifications_off_outlined,
                                    label: 'Skip for Now',
                                    onTap: () => handleNotificationChoice(
                                      allow: false,
                                    ),
                                  ),
                                ] else if (currentStep.value ==
                                    _PermChatStep.storage) ...[
                                  _PermQuickChip(
                                    icon: Icons.camera_alt_rounded,
                                    label: 'Allow Camera & Storage',
                                    onTap: () => handleStorageChoice(
                                      allow: true,
                                    ),
                                  ),
                                  _PermQuickChip(
                                    icon: Icons.block_rounded,
                                    label: 'Skip for Now',
                                    onTap: () => handleStorageChoice(
                                      allow: false,
                                    ),
                                  ),
                                ],
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

class _PermQuickChip extends StatelessWidget {
  const _PermQuickChip({
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
