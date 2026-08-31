import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';
import 'package:kortex/src/shared/widgets/typewriter_text.dart';

enum ChatSender { syllabot, user }

class CalibrationChatMessage {
  const CalibrationChatMessage({
    required this.id,
    required this.sender,
    required this.text,
  });

  final String id;
  final ChatSender sender;
  final String text;
}

/// Conversational AI Chat calibration view with Syllabot AI.
///
/// Fully context-driven with animated "Thinking..." state and live typewriter
/// streaming on bot messages.
class CalibrationChatView extends HookWidget {
  const CalibrationChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final cubit = context.read<CalibrationCubit>();
    final state = context.watch<CalibrationCubit>().state;

    final scrollController = useScrollController();
    final isThinking = useState<bool>(false);
    final thinkingLabel = useState<String>('Thinking...');
    final isTyping = useState<bool>(false);
    final latestBotMsgId = useState<String>('');

    // Setup initial messages based on current step
    final messages = useState<List<CalibrationChatMessage>>([
      CalibrationChatMessage(
        id: 'msg_welcome',
        sender: ChatSender.syllabot,
        text: l10n.calibrationChatWelcome,
      ),
      CalibrationChatMessage(
        id: 'msg_focus',
        sender: ChatSender.syllabot,
        text: l10n.calibrationChatFocusPrompt,
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

    void addMessage(String text, {required bool isBot}) {
      final msgId =
          '${isBot ? 'bot' : 'usr'}_${DateTime.now().millisecondsSinceEpoch}';
      final msg = CalibrationChatMessage(
        id: msgId,
        sender: isBot ? ChatSender.syllabot : ChatSender.user,
        text: text,
      );
      messages.value = [...messages.value, msg];
      if (isBot) {
        latestBotMsgId.value = msgId;
        isTyping.value = true;
      }
      scrollToBottom();
    }

    void handleOptionSelected(
      String label,
      VoidCallback action, {
      String? nextBotPrompt,
      String? customThinkingText,
    }) {
      unawaited(HapticFeedback.lightImpact());
      addMessage(label, isBot: false);
      action();

      isThinking.value = true;
      thinkingLabel.value = customThinkingText ?? 'Thinking...';
      scrollToBottom();

      Timer(const Duration(milliseconds: 950), () {
        if (!context.mounted) return;
        isThinking.value = false;

        if (nextBotPrompt != null) {
          addMessage(nextBotPrompt, isBot: true);
        }
      });
    }

    final isInputNeeded = !isThinking.value && !isTyping.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                // 1. Message Thread
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
                      final isBot = msg.sender == ChatSender.syllabot;
                      final isStreaming =
                          isBot &&
                          msg.id == latestBotMsgId.value &&
                          isTyping.value;

                      return Semantics(
                        container: true,
                        label: isBot
                            ? 'Syllabot message: ${msg.text}'
                            : 'Your response: ${msg.text}',
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isBot
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isBot) ...[
                                const SyllabotAvatar(size: 36),
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBot
                                        ? (isDark
                                              ? colors.surfaceSecondary
                                                    .withAlpha(160)
                                              : colors.surfacePrimary)
                                        : colors.primary,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: isBot
                                          ? const Radius.circular(4)
                                          : const Radius.circular(18),
                                      bottomRight: isBot
                                          ? const Radius.circular(18)
                                          : const Radius.circular(4),
                                    ),
                                    border: Border.all(
                                      color: isBot
                                          ? (isDark
                                                ? colors.surfaceBorderHighlight
                                                      .withAlpha(70)
                                                : colors.surfaceBorder)
                                          : colors.primary,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(
                                          isDark ? 40 : 8,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isBot
                                      ? TypewriterText(
                                          text: msg.text,
                                          isStreaming: isStreaming,
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
                                                color: Colors.white,
                                                fontSize: 14,
                                                height: 1.35,
                                              ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Context-Driven Quick Action Choices (Only after typing)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: !isInputNeeded
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(state.currentStepIndex),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                                if (state.currentStepIndex == 0) ...[
                                  _QuickChip(
                                    icon: Icons.school_rounded,
                                    label: l10n.calibrationFocusHigherEd,
                                    onTap: () => handleOptionSelected(
                                      l10n.calibrationFocusHigherEd,
                                      () {
                                        cubit
                                          ..setAcademicFocus(
                                            AcademicFocus.higherEducation,
                                          )
                                          ..nextStep();
                                      },
                                      nextBotPrompt:
                                          l10n.calibrationChatLevelPrompt,
                                      customThinkingText: 'Configuring...',
                                    ),
                                  ),
                                  _QuickChip(
                                    icon: Icons.menu_book_rounded,
                                    label: l10n.calibrationFocusHighSchool,
                                    onTap: () => handleOptionSelected(
                                      l10n.calibrationFocusHighSchool,
                                      () {
                                        cubit
                                          ..setAcademicFocus(
                                            AcademicFocus.highSchool,
                                          )
                                          ..nextStep();
                                      },
                                      nextBotPrompt:
                                          l10n.calibrationChatLevelPrompt,
                                      customThinkingText: 'Configuring...',
                                    ),
                                  ),
                                ] else if (state.currentStepIndex == 1) ...[
                                  if (state.profile.focus ==
                                      AcademicFocus.higherEducation) ...[
                                    _QuickChip(
                                      label: 'BSc (Bachelor)',
                                      onTap: () => handleOptionSelected(
                                        'BSc (Bachelor)',
                                        () {
                                          cubit
                                            ..setHigherEdLevel(
                                              HigherEdLevel.bsc,
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Updating level...',
                                      ),
                                    ),
                                    _QuickChip(
                                      label: 'MSc (Master)',
                                      onTap: () => handleOptionSelected(
                                        'MSc (Master)',
                                        () {
                                          cubit
                                            ..setHigherEdLevel(
                                              HigherEdLevel.msc,
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Updating level...',
                                      ),
                                    ),
                                    _QuickChip(
                                      label: 'PhD (Doctorate)',
                                      onTap: () => handleOptionSelected(
                                        'PhD (Doctorate)',
                                        () {
                                          cubit
                                            ..setHigherEdLevel(
                                              HigherEdLevel.phd,
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Updating level...',
                                      ),
                                    ),
                                    _QuickChip(
                                      label: 'OND / HND',
                                      onTap: () => handleOptionSelected(
                                        'OND / HND',
                                        () {
                                          cubit
                                            ..setHigherEdLevel(
                                              HigherEdLevel.ond,
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Updating level...',
                                      ),
                                    ),
                                  ] else ...[
                                    _QuickChip(
                                      label: 'WAEC / GCE',
                                      onTap: () => handleOptionSelected(
                                        'WAEC / GCE',
                                        () {
                                          cubit
                                            ..setHighSchoolExam(
                                              'WAEC / GCE',
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Setting exam...',
                                      ),
                                    ),
                                    _QuickChip(
                                      label: 'JAMB / UTME',
                                      onTap: () => handleOptionSelected(
                                        'JAMB / UTME',
                                        () {
                                          cubit
                                            ..setHighSchoolExam(
                                              'JAMB / UTME',
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Setting exam...',
                                      ),
                                    ),
                                    _QuickChip(
                                      label: 'NECO / SSCE',
                                      onTap: () => handleOptionSelected(
                                        'NECO / SSCE',
                                        () {
                                          cubit
                                            ..setHighSchoolExam(
                                              'NECO / SSCE',
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Setting exam...',
                                      ),
                                    ),
                                    _QuickChip(
                                      label: 'SAT / IGCSE',
                                      onTap: () => handleOptionSelected(
                                        'SAT / IGCSE',
                                        () {
                                          cubit
                                            ..setHighSchoolExam(
                                              'SAT',
                                            )
                                            ..nextStep();
                                        },
                                        nextBotPrompt:
                                            l10n.calibrationChatFieldPrompt,
                                        customThinkingText: 'Setting exam...',
                                      ),
                                    ),
                                  ],
                                ] else if (state.currentStepIndex == 2) ...[
                                  _QuickChip(
                                    icon: Icons.computer_rounded,
                                    label: 'Computer Science & AI',
                                    onTap: () => handleOptionSelected(
                                      'Computer Science & AI',
                                      () {
                                        if (state.profile.focus ==
                                            AcademicFocus.higherEducation) {
                                          cubit.setHigherEdField(
                                            'Computer Science & AI',
                                          );
                                        } else {
                                          cubit.toggleHighSchoolSubject(
                                            'Mathematics (Core)',
                                          );
                                        }
                                        cubit.nextStep();
                                      },
                                      nextBotPrompt:
                                          l10n.calibrationChatGoalPrompt,
                                      customThinkingText:
                                          'Configuring model...',
                                    ),
                                  ),
                                  _QuickChip(
                                    icon: Icons.gavel_rounded,
                                    label: 'Law & Legal Studies',
                                    onTap: () => handleOptionSelected(
                                      'Law & Legal Studies',
                                      () {
                                        if (state.profile.focus ==
                                            AcademicFocus.higherEducation) {
                                          cubit.setHigherEdField(
                                            'Law & Legal Studies',
                                          );
                                        } else {
                                          cubit.toggleHighSchoolSubject(
                                            'Government',
                                          );
                                        }
                                        cubit.nextStep();
                                      },
                                      nextBotPrompt:
                                          l10n.calibrationChatGoalPrompt,
                                      customThinkingText:
                                          'Configuring model...',
                                    ),
                                  ),
                                  _QuickChip(
                                    icon: Icons.local_hospital_rounded,
                                    label: 'Medicine & Health Sciences',
                                    onTap: () => handleOptionSelected(
                                      'Medicine & Health Sciences',
                                      () {
                                        if (state.profile.focus ==
                                            AcademicFocus.higherEducation) {
                                          cubit.setHigherEdField(
                                            'Medicine & Health Sciences',
                                          );
                                        } else {
                                          cubit.toggleHighSchoolSubject(
                                            'Biology',
                                          );
                                        }
                                        cubit.nextStep();
                                      },
                                      nextBotPrompt:
                                          l10n.calibrationChatGoalPrompt,
                                      customThinkingText:
                                          'Configuring model...',
                                    ),
                                  ),
                                  _QuickChip(
                                    icon: Icons.attach_money_rounded,
                                    label: 'Business & Finance',
                                    onTap: () => handleOptionSelected(
                                      'Business & Finance',
                                      () {
                                        if (state.profile.focus ==
                                            AcademicFocus.higherEducation) {
                                          cubit.setHigherEdField(
                                            'Business & Finance',
                                          );
                                        } else {
                                          cubit.toggleHighSchoolSubject(
                                            'Economics',
                                          );
                                        }
                                        cubit.nextStep();
                                      },
                                      nextBotPrompt:
                                          l10n.calibrationChatGoalPrompt,
                                      customThinkingText:
                                          'Configuring model...',
                                    ),
                                  ),
                                ] else if (state.currentStepIndex == 3) ...[
                                  _QuickChip(
                                    icon: Icons.rocket_launch_rounded,
                                    label: l10n.calibrationFinish,
                                    onTap: () {
                                      handleOptionSelected(
                                        l10n.calibrationFinish,
                                        () {
                                          unawaited(cubit.finishCalibration());
                                        },
                                        customThinkingText:
                                            'Calibrating neural engine...',
                                      );
                                    },
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({
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
          onTap: onTap,
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
