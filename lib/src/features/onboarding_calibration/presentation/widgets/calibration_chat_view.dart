import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                              children: _buildQuickChips(
                                context: context,
                                cubit: cubit,
                                state: state,
                                l10n: l10n,
                                handleOptionSelected: handleOptionSelected,
                              ),
                            ),
                          ),
                        ),
                ),

                // 3. Launch Action Button (Consistent Primary AppButton)
                if (state.currentStepIndex == 3 ||
                    (state.canProceed && state.currentStepIndex >= 2))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: AppButton(
                      text: l10n.calibrationFinish,
                      isLoading: state.isSubmitting,
                      onPressed: state.canProceed
                          ? () {
                              unawaited(cubit.finishCalibration());
                            }
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildQuickChips({
    required BuildContext context,
    required CalibrationCubit cubit,
    required CalibrationState state,
    required AppLocalizations l10n,
    required void Function(
      String label,
      VoidCallback action, {
      String? nextBotPrompt,
      String? customThinkingText,
    }) handleOptionSelected,
  }) {
    if (state.currentStepIndex == 0) {
      return [
        _QuickChip(
          icon: Icons.school_rounded,
          label: l10n.calibrationFocusHigherEd,
          onTap: () => handleOptionSelected(
            l10n.calibrationFocusHigherEd,
            () {
              cubit
                ..setAcademicFocus(AcademicFocus.higherEducation)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionA2,
            customThinkingText: 'Configuring curriculum...',
          ),
        ),
        _QuickChip(
          icon: Icons.menu_book_rounded,
          label: l10n.calibrationFocusHighSchool,
          onTap: () => handleOptionSelected(
            l10n.calibrationFocusHighSchool,
            () {
              cubit
                ..setAcademicFocus(AcademicFocus.highSchool)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionB2,
            customThinkingText: 'Configuring exam tracks...',
          ),
        ),
      ];
    }

    if (state.currentStepIndex == 1) {
      if (state.profile.focus == AcademicFocus.higherEducation) {
        return [
          _QuickChip(
            icon: Icons.history_edu_rounded,
            label: l10n.calibrationOptionBSc,
            onTap: () => handleOptionSelected(
              l10n.calibrationOptionBSc,
              () {
                cubit
                  ..setHigherEdLevel(HigherEdLevel.bsc)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionA3,
              customThinkingText: 'Updating degree level...',
            ),
          ),
          _QuickChip(
            icon: Icons.workspace_premium_rounded,
            label: l10n.calibrationOptionMSc,
            onTap: () => handleOptionSelected(
              l10n.calibrationOptionMSc,
              () {
                cubit
                  ..setHigherEdLevel(HigherEdLevel.msc)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionA3,
              customThinkingText: 'Updating degree level...',
            ),
          ),
          _QuickChip(
            icon: Icons.psychology_alt_rounded,
            label: l10n.calibrationOptionPhD,
            onTap: () => handleOptionSelected(
              l10n.calibrationOptionPhD,
              () {
                cubit
                  ..setHigherEdLevel(HigherEdLevel.phd)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionA3,
              customThinkingText: 'Updating degree level...',
            ),
          ),
          _QuickChip(
            icon: Icons.menu_book_rounded,
            label: l10n.calibrationOptionOND,
            onTap: () => handleOptionSelected(
              l10n.calibrationOptionOND,
              () {
                cubit
                  ..setHigherEdLevel(HigherEdLevel.ond)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionA3,
              customThinkingText: 'Updating degree level...',
            ),
          ),
          _QuickChip(
            icon: Icons.auto_stories_rounded,
            label: l10n.calibrationOptionHND,
            onTap: () => handleOptionSelected(
              l10n.calibrationOptionHND,
              () {
                cubit
                  ..setHigherEdLevel(HigherEdLevel.hnd)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionA3,
              customThinkingText: 'Updating degree level...',
            ),
          ),
        ];
      } else {
        final exams = [
          (l10n.calibrationExamWAEC, Icons.school_rounded),
          (l10n.calibrationExamJAMB, Icons.quiz_rounded),
          (l10n.calibrationExamNECO, Icons.assignment_turned_in_rounded),
          (l10n.calibrationExamSAT, Icons.public_rounded),
          (l10n.calibrationExamIGCSE, Icons.military_tech_rounded),
          (l10n.calibrationExamIELTS, Icons.translate_rounded),
        ];
        return exams.map((e) {
          return _QuickChip(
            icon: e.$2,
            label: e.$1,
            onTap: () => handleOptionSelected(
              e.$1,
              () {
                cubit
                  ..setHighSchoolExam(e.$1)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionB3,
              customThinkingText: 'Loading exam bank...',
            ),
          );
        }).toList();
      }
    }

    if (state.currentStepIndex == 2) {
      if (state.profile.focus == AcademicFocus.higherEducation) {
        final fields = [
          (l10n.calibrationFieldComputerScience, Icons.memory_rounded),
          (l10n.calibrationFieldMedicine, Icons.medical_services_rounded),
          (l10n.calibrationFieldLaw, Icons.gavel_rounded),
          (l10n.calibrationFieldBusiness, Icons.business_center_rounded),
          (l10n.calibrationFieldHumanities, Icons.menu_book_rounded),
          (l10n.calibrationFieldSocialSciences, Icons.groups_rounded),
          (l10n.calibrationFieldMath, Icons.functions_rounded),
          (l10n.calibrationFieldPhysics, Icons.blur_on_rounded),
          (l10n.calibrationFieldChemEng, Icons.science_rounded),
          (
            l10n.calibrationFieldRobotics,
            Icons.precision_manufacturing_rounded,
          ),
        ];
        return fields.map((f) {
          return _QuickChip(
            icon: f.$2,
            label: f.$1,
            onTap: () => handleOptionSelected(
              f.$1,
              () {
                cubit
                  ..setHigherEdField(f.$1)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionA4,
              customThinkingText: 'Configuring domain models...',
            ),
          );
        }).toList();
      } else {
        final exam = state.profile.highSchoolExam ?? '';
        final isSat = exam.contains('SAT');
        final isIelts = exam.contains('IELTS') || exam.contains('TOEFL');
        final isIgcse = exam.contains('IGCSE') || exam.contains('A-Level');

        final List<(String, IconData)> subjects;
        if (isSat) {
          subjects = [
            ('SAT Reading Comprehension', Icons.menu_book_rounded),
            ('SAT Writing & Language', Icons.spellcheck_rounded),
            ('SAT Math: Heart of Algebra', Icons.calculate_rounded),
            ('SAT Math: Advanced & Problem Solving', Icons.functions_rounded),
          ];
        } else if (isIelts) {
          subjects = [
            ('Reading Section', Icons.menu_book_rounded),
            ('Listening Section', Icons.headphones_rounded),
            ('Writing (Task 1 & 2)', Icons.edit_note_rounded),
            ('Speaking Section', Icons.mic_rounded),
          ];
        } else if (isIgcse) {
          subjects = [
            ('Cambridge IGCSE Mathematics', Icons.calculate_rounded),
            ('Additional Mathematics', Icons.functions_rounded),
            ('English Language & Literature', Icons.spellcheck_rounded),
            ('IGCSE Physics', Icons.flash_on_rounded),
            ('IGCSE Chemistry', Icons.science_rounded),
            ('IGCSE Biology', Icons.biotech_rounded),
            ('Computer Science', Icons.computer_rounded),
            ('Economics & Business', Icons.trending_up_rounded),
            ('Accounting', Icons.account_balance_rounded),
          ];
        } else {
          subjects = [
            (l10n.calibrationSubjectCoreMath, Icons.calculate_rounded),
            (l10n.calibrationSubjectEnglish, Icons.spellcheck_rounded),
            (l10n.calibrationSubjectPhysics, Icons.flash_on_rounded),
            (l10n.calibrationSubjectChemistry, Icons.science_rounded),
            (l10n.calibrationSubjectBiology, Icons.biotech_rounded),
            (l10n.calibrationSubjectFurtherMath, Icons.functions_rounded),
            (l10n.calibrationSubjectAccounting, Icons.account_balance_rounded),
            (l10n.calibrationSubjectEconomics, Icons.trending_up_rounded),
            (l10n.calibrationSubjectCommerce, Icons.store_rounded),
            (l10n.calibrationSubjectLiterature, Icons.menu_book_rounded),
            (
              l10n.calibrationSubjectGovernment,
              Icons.account_balance_wallet_rounded,
            ),
            (l10n.calibrationSubjectHistory, Icons.history_edu_rounded),
            (l10n.calibrationSubjectCRK, Icons.church_rounded),
          ];
        }

        return subjects.map((s) {
          final isSelected =
              state.profile.highSchoolSubjects.contains(s.$1);
          return _QuickChip(
            icon: s.$2,
            label: s.$1,
            isSelected: isSelected,
            onTap: () => handleOptionSelected(
              s.$1,
              () {
                cubit
                  ..toggleHighSchoolSubject(s.$1)
                  ..nextStep();
              },
              nextBotPrompt: l10n.calibrationQuestionB4,
              customThinkingText: 'Mapping curriculum...',
            ),
          );
        }).toList();
      }
    }

    if (state.currentStepIndex == 3) {
      if (state.profile.focus == AcademicFocus.higherEducation) {
        final goals = [
          (l10n.calibrationGoalThesis, Icons.article_rounded),
          (l10n.calibrationGoalCaseLaw, Icons.gavel_rounded),
          (l10n.calibrationGoalSocratic, Icons.psychology_rounded),
          (l10n.calibrationGoalSpacedRep, Icons.schedule_rounded),
          (l10n.calibrationGoalMockExams, Icons.timer_outlined),
          (l10n.calibrationGoalEssayPrep, Icons.edit_note_rounded),
        ];
        return goals.map((g) {
          final isSelected = state.profile.higherEdGoals.contains(g.$1);
          return _QuickChip(
            icon: g.$2,
            label: g.$1,
            isSelected: isSelected,
            onTap: () => handleOptionSelected(
              g.$1,
              () {
                cubit.toggleHigherEdGoal(g.$1);
              },
              nextBotPrompt:
                  'Curriculum calibrated! Ready to launch your workspace.',
              customThinkingText: 'Configuring tools...',
            ),
          );
        }).toList();
      } else {
        final timelines = [
          (l10n.calibrationTimeline1Month, Icons.local_fire_department_rounded),
          (l10n.calibrationTimeline3Months, Icons.speed_rounded),
          (l10n.calibrationTimeline6Months, Icons.calendar_month_rounded),
          (l10n.calibrationTimelineNextYear, Icons.hourglass_top_rounded),
        ];
        return timelines.map((t) {
          final isSelected = state.profile.highSchoolTimeline == t.$1;
          return _QuickChip(
            icon: t.$2,
            label: t.$1,
            isSelected: isSelected,
            onTap: () => handleOptionSelected(
              t.$1,
              () {
                cubit.setHighSchoolTimeline(t.$1);
              },
              nextBotPrompt: 'Study schedule synchronized! '
                  'Ready to launch your workspace.',
              customThinkingText: 'Pacing schedule...',
            ),
          );
        }).toList();
      }
    }

    return [];
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
    this.isSelected = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Quick action: $label',
        child: ShrinkableButton(
          shrinkScale: 0.98,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected
                  ? colors.primary.withAlpha(isDark ? 80 : 35)
                  : (isDark
                      ? colors.surfaceSecondary.withAlpha(140)
                      : colors.surfacePrimary),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : (isDark
                        ? colors.surfaceBorderHighlight.withAlpha(70)
                        : colors.surfaceBorder),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? colors.primary : colors.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: typography.callout.semiBold.copyWith(
                    color: isSelected ? colors.primary : colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: colors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
