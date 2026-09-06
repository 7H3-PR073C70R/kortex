import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/constants/subject_catalog.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/curriculum_icon_resolver.dart';
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
/// Features:
/// - Real-time conversational context tracking
/// - Multi-selection subject panel with 1-tap combination presets
/// - Stream category filtering and live search
/// - Interactive text input bar for natural typing or quick tap
/// - Fully skippable and non-compulsory progression
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
    final textController = useTextEditingController();
    final isThinking = useState<bool>(false);
    final thinkingLabel = useState<String>('Thinking...');
    final isTyping = useState<bool>(false);
    final latestBotMsgId = useState<String>('');

    // Stream and search states for subjects in chat mode
    final subjectSearch = useState<String>('');
    final selectedStream = useState<String>('All');

    // Build dynamic conversation messages based on current state & step
    final messages = useState<List<CalibrationChatMessage>>([]);

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

    // Initialize or synchronize messages when step index changes
    useEffect(() {
      final initial = <CalibrationChatMessage>[
        CalibrationChatMessage(
          id: 'welcome_1',
          sender: ChatSender.syllabot,
          text: l10n.calibrationChatWelcome,
        ),
        CalibrationChatMessage(
          id: 'prompt_step_0',
          sender: ChatSender.syllabot,
          text: l10n.calibrationChatFocusPrompt,
        ),
      ];

      // Add historical messages if user is already at step 1, 2, or 3
      if (state.currentStepIndex >= 1) {
        final focusName = state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationFocusHigherEd
            : l10n.calibrationFocusHighSchool;
        initial.add(CalibrationChatMessage(
          id: 'ans_step_0',
          sender: ChatSender.user,
          text: focusName,
        ));
        final nextPrompt = state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationQuestionA2
            : l10n.calibrationQuestionB2;
        initial.add(CalibrationChatMessage(
          id: 'prompt_step_1',
          sender: ChatSender.syllabot,
          text: nextPrompt,
        ));
      }

      if (state.currentStepIndex >= 2) {
        final step1Ans = state.profile.focus == AcademicFocus.higherEducation
            ? (state.profile.higherEdLevel?.name.toUpperCase() ?? 'Undergraduate')
            : (state.profile.highSchoolExam ?? 'WAEC / WASSCE');
        initial.add(CalibrationChatMessage(
          id: 'ans_step_1',
          sender: ChatSender.user,
          text: step1Ans,
        ));
        final nextPrompt = state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationQuestionA3
            : l10n.calibrationQuestionB3;
        initial.add(CalibrationChatMessage(
          id: 'prompt_step_2',
          sender: ChatSender.syllabot,
          text: nextPrompt,
        ));
      }

      if (state.currentStepIndex >= 3) {
        final subjectsCount = state.profile.highSchoolSubjects.length;
        final step2Ans = state.profile.focus == AcademicFocus.higherEducation
            ? (state.profile.higherEdField ?? 'General Studies')
            : (subjectsCount > 0
                ? 'Selected $subjectsCount subjects: ${state.profile.highSchoolSubjects.take(3).join(', ')}${subjectsCount > 3 ? '...' : ''}'
                : 'Skipped subject selection for now');
        initial.add(CalibrationChatMessage(
          id: 'ans_step_2',
          sender: ChatSender.user,
          text: step2Ans,
        ));
        final nextPrompt = state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationQuestionA4
            : l10n.calibrationQuestionB4;
        initial.add(CalibrationChatMessage(
          id: 'prompt_step_3',
          sender: ChatSender.syllabot,
          text: nextPrompt,
        ));
      }

      messages.value = initial;
      scrollToBottom();
      return null;
    }, [state.currentStepIndex]);

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

      Timer(const Duration(milliseconds: 700), () {
        if (!context.mounted) return;
        isThinking.value = false;

        if (nextBotPrompt != null) {
          addMessage(nextBotPrompt, isBot: true);
        }
      });
    }

    void handleTextSubmitted(String rawText) {
      final text = rawText.trim();
      if (text.isEmpty) return;
      textController.clear();

      final lower = text.toLowerCase();
      if (lower == 'skip' || lower == 'skip calibration') {
        unawaited(cubit.skipCalibration());
        return;
      }

      if (state.currentStepIndex == 0) {
        if (lower.contains('uni') || lower.contains('degree') || lower.contains('poly')) {
          handleOptionSelected(
            l10n.calibrationFocusHigherEd,
            () {
              cubit
                ..setAcademicFocus(AcademicFocus.higherEducation)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionA2,
          );
        } else {
          handleOptionSelected(
            l10n.calibrationFocusHighSchool,
            () {
              cubit
                ..setAcademicFocus(AcademicFocus.highSchool)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionB2,
          );
        }
      } else if (state.currentStepIndex == 1) {
        if (state.profile.focus == AcademicFocus.higherEducation) {
          final level = lower.contains('master') || lower.contains('msc')
              ? HigherEdLevel.msc
              : (lower.contains('phd') || lower.contains('doctor')
                  ? HigherEdLevel.phd
                  : HigherEdLevel.bsc);
          handleOptionSelected(
            text,
            () {
              cubit
                ..setHigherEdLevel(level)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionA3,
          );
        } else {
          handleOptionSelected(
            text,
            () {
              cubit
                ..setHighSchoolExam(text)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionB3,
          );
        }
      } else if (state.currentStepIndex == 2) {
        if (state.profile.focus == AcademicFocus.higherEducation) {
          handleOptionSelected(
            text,
            () {
              cubit
                ..setHigherEdField(text)
                ..nextStep();
            },
            nextBotPrompt: l10n.calibrationQuestionA4,
          );
        } else {
          // Check if user typed "done", "next", or subject names
          if (lower.contains('done') || lower.contains('next') || lower.contains('continue')) {
            final count = state.profile.highSchoolSubjects.length;
            handleOptionSelected(
              count > 0 ? 'Confirmed $count subjects' : 'Proceed without subjects',
              cubit.nextStep,
              nextBotPrompt: l10n.calibrationQuestionB4,
            );
          } else {
            cubit.toggleHighSchoolSubject(text);
          }
        }
      } else if (state.currentStepIndex == 3) {
        if (state.profile.focus == AcademicFocus.higherEducation) {
          cubit.toggleHigherEdGoal(text);
          unawaited(cubit.finishCalibration());
        } else {
          handleOptionSelected(
            text,
            () {
              cubit.setHighSchoolTimeline(text);
              unawaited(cubit.finishCalibration());
            },
            nextBotPrompt: 'Curriculum calibrated! Launching your workspace...',
          );
        }
      }
    }

    final isInputNeeded = !isThinking.value && !isTyping.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                // ── 1. Message Thread ─────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
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
                                const SyllabotAvatar(size: 34),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBot
                                        ? (isDark
                                            ? colors.surfaceSecondary
                                                .withAlpha(160)
                                            : colors.surfacePrimary)
                                        : colors.primary,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isBot
                                          ? const Radius.circular(4)
                                          : const Radius.circular(16),
                                      bottomRight: isBot
                                          ? const Radius.circular(16)
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
                                        color: colors.black.withAlpha(
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
                                                fontSize: 13.5,
                                                height: 1.35,
                                              ),
                                        )
                                      : Text(
                                          msg.text,
                                          style: typography.callout.regular
                                              .copyWith(
                                                color: colors.white,
                                                fontSize: 13.5,
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

                // ── 2. Contextual Options Panel ──────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: !isInputNeeded
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(state.currentStepIndex),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(140)
                                : colors.surfacePrimary.withAlpha(220),
                            border: Border(
                              top: BorderSide(
                                color: colors.surfaceBorder.withAlpha(
                                  isDark ? 70 : 40,
                                ),
                              ),
                            ),
                          ),
                          child: _buildStepOptions(
                            context: context,
                            cubit: cubit,
                            state: state,
                            l10n: l10n,
                            handleOptionSelected: handleOptionSelected,
                            subjectSearch: subjectSearch,
                            selectedStream: selectedStream,
                          ),
                        ),
                ),

                // ── 3. Interactive Text Input Bar ────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(160)
                        : colors.surfacePrimary,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(40)
                                : colors.surfaceBorder.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(60)
                                  : colors.surfaceBorder,
                            ),
                          ),
                          child: TextField(
                            controller: textController,
                            style: typography.callout.regular.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13.5,
                            ),
                            onSubmitted: handleTextSubmitted,
                            decoration: InputDecoration(
                              hintText: state.currentStepIndex == 2 &&
                                      state.profile.focus == AcademicFocus.highSchool
                                  ? 'Type or tap subjects above...'
                                  : 'Type a reply or tap above...',
                              hintStyle: typography.callout.regular.copyWith(
                                color: colors.textSecondary.withAlpha(140),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShrinkableButton(
                        onTap: () => handleTextSubmitted(textController.text),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepOptions({
    required BuildContext context,
    required CalibrationCubit cubit,
    required CalibrationState state,
    required AppLocalizations l10n,
    required void Function(
      String label,
      VoidCallback action, {
      String? nextBotPrompt,
      String? customThinkingText,
    })
    handleOptionSelected,
    required ValueNotifier<String> subjectSearch,
    required ValueNotifier<String> selectedStream,
  }) {
    // ── Step 0: Academic Focus ───────────────────────────────────────────────
    if (state.currentStepIndex == 0) {
      return Row(
        children: [
          Expanded(
            child: _QuickChip(
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
                customThinkingText: 'Personalizing curriculum...',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickChip(
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
          ),
        ],
      );
    }

    // ── Step 1: Exam / Degree Level ──────────────────────────────────────────
    if (state.currentStepIndex == 1) {
      if (state.profile.focus == AcademicFocus.higherEducation) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
              ),
            ),
          ],
        );
      } else {
        final exams = [
          (l10n.calibrationExamWAEC, Icons.school_rounded),
          (l10n.calibrationExamJAMB, Icons.quiz_rounded),
          (l10n.calibrationExamNECO, Icons.assignment_turned_in_rounded),
          (l10n.calibrationExamSAT, Icons.public_rounded),
          (l10n.calibrationExamIGCSE, Icons.military_tech_rounded),
          (l10n.calibrationExamIELTS, Icons.translate_rounded),
        ];

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: exams.map((e) {
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
                customThinkingText: 'Loading ${e.$1} curriculum...',
              ),
            );
          }).toList(),
        );
      }
    }

    // ── Step 2: High School Subjects Selection or Higher Ed Field ────────────
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
        ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fields.map((f) {
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
              ),
            );
          }).toList(),
        );
      } else {
        // High school subjects selection: Interactive Multi-Select Panel!
        return _ChatSubjectSelectionPanel(
          state: state,
          cubit: cubit,
          handleOptionSelected: handleOptionSelected,
          subjectSearch: subjectSearch,
          selectedStream: selectedStream,
        );
      }
    }

    // ── Step 3: Goals or Timelines ───────────────────────────────────────────
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
        final selectedGoals = state.profile.higherEdGoals;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: goals.map((g) {
                final isSelected = selectedGoals.contains(g.$1);
                return _QuickChip(
                  icon: g.$2,
                  label: g.$1,
                  isSelected: isSelected,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    cubit.toggleHigherEdGoal(g.$1);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: selectedGoals.isNotEmpty
                        ? 'Finish Calibration (${selectedGoals.length})'
                        : 'Finish Setup',
                    isLoading: state.isSubmitting,
                    onPressed: () {
                      unawaited(cubit.finishCalibration());
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        final timelines = [
          (l10n.calibrationTimeline1Month, Icons.local_fire_department_rounded),
          (l10n.calibrationTimeline3Months, Icons.speed_rounded),
          (l10n.calibrationTimeline6Months, Icons.calendar_month_rounded),
          (l10n.calibrationTimelineNextYear, Icons.hourglass_top_rounded),
        ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timelines.map((t) {
            return _QuickChip(
              icon: t.$2,
              label: t.$1,
              onTap: () => handleOptionSelected(
                t.$1,
                () {
                  cubit.setHighSchoolTimeline(t.$1);
                  unawaited(cubit.finishCalibration());
                },
                nextBotPrompt:
                    'All set! Calibrating your personalized neural feed...',
                customThinkingText: 'Configuring active recall...',
              ),
            );
          }).toList(),
        );
      }
    }

    return const SizedBox.shrink();
  }
}

/// Dynamic multi-select subject component embedded inside the Chat flow.
class _ChatSubjectSelectionPanel extends StatelessWidget {
  const _ChatSubjectSelectionPanel({
    required this.state,
    required this.cubit,
    required this.handleOptionSelected,
    required this.subjectSearch,
    required this.selectedStream,
  });

  final CalibrationState state;
  final CalibrationCubit cubit;
  final void Function(
    String label,
    VoidCallback action, {
    String? nextBotPrompt,
    String? customThinkingText,
  })
  handleOptionSelected;
  final ValueNotifier<String> subjectSearch;
  final ValueNotifier<String> selectedStream;

  String _cleanStream(String department) {
    if (department.contains('Core')) return 'Core';
    if (department.contains('Science')) return 'Sciences';
    if (department.contains('Commercial')) return 'Commercial';
    if (department.contains('Art')) return 'Arts';
    if (department.contains('SAT')) return 'SAT Prep';
    final parts = department.split('-');
    return parts.last.trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedSubjects = state.profile.highSchoolSubjects;
    final allCourses = state.highSchoolCatalogCourses;

    final exam = (state.profile.highSchoolExam ?? '').toUpperCase();
    final isSat = exam.contains('SAT');

    // 1-Tap Combination Presets
    final presets = isSat
        ? kCuratedSubjectPresets.where((p) => p.id.startsWith('sat')).toList()
        : kCuratedSubjectPresets.where((p) => !p.id.startsWith('sat')).toList();

    // Stream filters
    final streamSet = <String>{};
    for (final course in allCourses) {
      streamSet.add(_cleanStream(course.department));
    }
    final streams = ['All', ...streamSet];

    // Filter courses
    final query = subjectSearch.value.trim().toLowerCase();
    final filtered = allCourses.where((c) {
      final matchesStream = selectedStream.value == 'All' ||
          _cleanStream(c.department).toLowerCase() ==
              selectedStream.value.toLowerCase();
      if (!matchesStream) return false;

      if (query.isEmpty) return true;
      return c.title.toLowerCase().contains(query) ||
          c.courseCode.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Presets row
        if (presets.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                final isActive = p.subjectTitles.every(selectedSubjects.contains);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.mediumImpact());
                      if (isActive) {
                        final updated = selectedSubjects
                            .where((s) => !p.subjectTitles.contains(s))
                            .toList();
                        cubit.setHighSchoolSubjects(updated);
                      } else {
                        final updated = <String>{
                          ...selectedSubjects,
                          ...p.subjectTitles,
                        }.toList();
                        cubit.setHighSchoolSubjects(updated);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.primary.withAlpha(isDark ? 65 : 35)
                            : (isDark
                                ? colors.surfaceSecondary.withAlpha(120)
                                : colors.surfacePrimary),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? colors.primary
                              : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(60)
                                  : colors.surfaceBorder),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.check_circle_rounded : p.icon,
                            size: 13,
                            color: isActive ? colors.primary : colors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            p.title,
                            style: typography.caption.bold.copyWith(
                              color: isActive ? colors.primary : colors.textPrimary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Stream tabs
        if (streams.length > 2) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: streams.map((s) {
                final isCurrent = selectedStream.value == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      selectedStream.value = s;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? colors.primary
                            : (isDark
                                ? colors.surfaceBorderHighlight.withAlpha(30)
                                : colors.surfaceBorder.withAlpha(60)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: typography.caption.bold.copyWith(
                          color: isCurrent ? Colors.white : colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Subject Chips Box (Scrollable wrap)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filtered.map((course) {
                final isSelected = selectedSubjects.contains(course.title);
                final resolvedIcon = resolveCurriculumIcon(course.iconName);

                return _QuickChip(
                  icon: resolvedIcon,
                  label: course.title,
                  isSelected: isSelected,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    cubit.toggleHighSchoolSubject(course.title);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Action Row: Counter + Done selecting button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${selectedSubjects.length} of ${allCourses.length} selected',
              style: typography.caption.semiBold.copyWith(
                color: selectedSubjects.isNotEmpty
                    ? colors.primary
                    : colors.textSecondary,
                fontSize: 12,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedSubjects.isNotEmpty) ...[
                  GestureDetector(
                    onTap: cubit.clearHighSchoolSubjects,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Clear',
                        style: typography.caption.semiBold.copyWith(
                          color: colors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
                ShrinkableButton(
                  onTap: () {
                    final count = selectedSubjects.length;
                    final msg = count > 0
                        ? 'Selected $count subjects: ${selectedSubjects.take(3).join(', ')}${count > 3 ? '...' : ''}'
                        : 'Skipped subject selection for now';
                    handleOptionSelected(
                      msg,
                      cubit.nextStep,
                      nextBotPrompt: l10n.calibrationQuestionB4,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      selectedSubjects.isNotEmpty
                          ? 'Done (${selectedSubjects.length}) →'
                          : 'Skip subjects →',
                      style: typography.caption.bold.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
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
          const SyllabotAvatar(size: 34),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(160)
                  : colors.surfacePrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(70)
                    : colors.surfaceBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 40 : 8),
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

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Quick action: $label',
      child: ShrinkableButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 40 : 20),
                      blurRadius: 8,
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
                  size: 14,
                  color: isSelected ? colors.primary : colors.primary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 5),
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: colors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
