import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Modal bottom sheet for searching and joining a 1v1 Quiz Duel match (QZ-13).
class QuizDuelMatchmakingSheet extends HookWidget {
  const QuizDuelMatchmakingSheet({
    super.key,
    this.initialSubject = 'Physics',
    this.initialExamBoard = 'WAEC',
  });

  final String initialSubject;
  final String initialExamBoard;

  static Future<void> show(
    BuildContext context, {
    String initialSubject = 'Physics',
    String initialExamBoard = 'WAEC',
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => QuizDuelMatchmakingSheet(
        initialSubject: initialSubject,
        initialExamBoard: initialExamBoard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedSubject = useState<String>(initialSubject);
    final selectedExamBoard = useState<String>(initialExamBoard);
    final isSearching = useState<bool>(false);

    final subjects = ['Physics', 'Mathematics', 'Chemistry', 'Biology', 'Economics', 'English'];
    final examBoards = ['WAEC', 'JAMB', 'NECO', 'IGCSE', 'SAT'];

    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    void startMatchmaking() {
      AppFeedback.selection();
      isSearching.value = true;
      final cubit = context.read<QuizDuelCubit>();
      cubit.startMatchmaking(
        subject: selectedSubject.value,
        examBoard: selectedExamBoard.value,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'You',
        avatarUrl: '⚡',
      );
    }

    return BlocListener<QuizDuelCubit, QuizDuelState>(
      listener: (context, state) {
        if (state.status == QuizDuelStatus.countdown ||
            state.status == QuizDuelStatus.inRound) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: context.read<QuizDuelCubit>(),
                child: const QuizDuelArenaPage(),
              ),
            ),
          );
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.surfaceBorder.withOpacity(0.5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1v1 Real-Time Quiz Duel',
                          style: typography.title2.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Fastest correct answers earn speed bonus points!',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppBadge(
                    label: 'P2P Live',
                    variant: AppBadgeVariant.success,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (isSearching.value) ...[
                // Radar Search Animation
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 110 + (pulseController.value * 20),
                              height: 110 + (pulseController.value * 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary.withOpacity(0.12 - (pulseController.value * 0.08)),
                                border: Border.all(
                                  color: colors.primary.withOpacity(0.4 + (pulseController.value * 0.4)),
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.primary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.primary.withOpacity(0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.radar_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Finding Academic Rival...',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Matching in ${selectedSubject.value} (${selectedExamBoard.value})',
                          style: typography.body.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Cancel Matchmaking',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    isSearching.value = false;
                    context.read<QuizDuelCubit>().leaveMatch();
                  },
                ),
              ] else ...[
                // Subject Selector
                Text(
                  'Select Subject',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subjects.map((sub) {
                    final isSelected = selectedSubject.value == sub;
                    return ChoiceChip(
                      label: Text(sub),
                      selected: isSelected,
                      selectedColor: colors.primary.withOpacity(0.2),
                      backgroundColor: colors.surfaceSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? colors.primary : colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          AppFeedback.selection();
                          selectedSubject.value = sub;
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Exam Board Selector
                Text(
                  'Exam Board / Standard',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: examBoards.map((board) {
                    final isSelected = selectedExamBoard.value == board;
                    return ChoiceChip(
                      label: Text(board),
                      selected: isSelected,
                      selectedColor: colors.secondary.withOpacity(0.2),
                      backgroundColor: colors.surfaceSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? colors.secondary : colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          AppFeedback.selection();
                          selectedExamBoard.value = board;
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Match Rule Highlights
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.surfaceBorder.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '5 Questions • 15s per Question • Max 150 pts/round with Speed Bonus',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                AppButton(
                  text: 'Find Opponent ⚡',
                  onPressed: startMatchmaking,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
