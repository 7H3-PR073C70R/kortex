import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_elo_tier.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_leaderboard_sheet.dart';
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
    final cubit = locator<QuizDuelCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => BlocProvider<QuizDuelCubit>.value(
        value: cubit,
        child: QuizDuelMatchmakingSheet(
          initialSubject: initialSubject,
          initialExamBoard: initialExamBoard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedSubject = useState<String>(initialSubject);
    final selectedQuestionCount = useState<int>(10);
    final isSearching = useState<bool>(false);
    final searchSeconds = useState<int>(0);

    useEffect(() {
      Timer? timer;
      if (isSearching.value) {
        searchSeconds.value = 0;
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          searchSeconds.value++;
        });
      }
      return () => timer?.cancel();
    }, [isSearching.value]);

    // Resolve exam board / standard directly from user's active profile track
    final authBloc = locator.isRegistered<AuthBloc>()
        ? locator<AuthBloc>()
        : null;
    final userTrack = authBloc?.state.userProfile?.targetTrack;
    final resolvedExamBoard = (userTrack != null && userTrack.isNotEmpty)
        ? userTrack
        : initialExamBoard;

    // Resolve subjects strictly from user's registered courses and active study decks
    final dashboardBloc = locator.isRegistered<DashboardBloc>()
        ? locator<DashboardBloc>()
        : null;
    final curatedCourses =
        dashboardBloc?.state.feed?.curatedCourses
            .map((c) => c.title.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final decksBloc = locator.isRegistered<DecksBloc>()
        ? locator<DecksBloc>()
        : null;
    final deckSubjects =
        decksBloc?.state.allDecks
            .map((d) => d.subject.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final userRegisteredCourses = {...curatedCourses, ...deckSubjects}.toList();

    // Fallback only if user has zero registered courses yet
    final subjects = userRegisteredCourses.isNotEmpty
        ? userRegisteredCourses
        : const [
            'Mathematics',
            'English',
            'Biology',
            'Physics',
            'Chemistry',
            'Economics',
          ];

    if (!subjects.contains(selectedSubject.value) && subjects.isNotEmpty) {
      selectedSubject.value = subjects.first;
    }

    final questionCounts = [5, 10, 15];

    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    );

    useEffect(() {
      unawaited(pulseController.repeat(reverse: true));
      return null;
    }, [pulseController]);

    void startMatchmaking() {
      AppFeedback.selection();
      isSearching.value = true;
      final profile = authBloc?.state.userProfile;
      final resolvedUserId = profile?.id ??
          authBloc?.state.user?.id ??
          'user_${DateTime.now().millisecondsSinceEpoch}';
      final resolvedDisplayName = (profile?.displayName != null &&
              profile!.displayName!.trim().isNotEmpty)
          ? profile.displayName!.trim()
          : 'Scholar';
      final resolvedAvatarUrl = profile?.photoUrl ?? '';

      unawaited(
        context.read<QuizDuelCubit>().startMatchmaking(
          subject: selectedSubject.value,
          examBoard: resolvedExamBoard,
          userId: resolvedUserId,
          displayName: resolvedDisplayName,
          avatarUrl: resolvedAvatarUrl,
          questionCount: selectedQuestionCount.value,
        ),
      );
    }

    final userProfile = authBloc?.state.userProfile;
    final userElo = userProfile?.eloRating ?? 1250;
    final eloTier = QuizDuelEloTier.fromElo(userElo);

    return BlocListener<QuizDuelCubit, QuizDuelState>(
      listener: (context, state) {
        if (state.status == QuizDuelStatus.countdown ||
            state.status == QuizDuelStatus.inRound) {
          final cubit = context.read<QuizDuelCubit>();
          Navigator.of(context).pop();
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<QuizDuelCubit>.value(
                  value: cubit,
                  child: const QuizDuelArenaPage(),
                ),
              ),
            ),
          );
        }
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(
                color: colors.surfaceBorder.withValues(alpha: 0.5),
              ),
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
                        color: colors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.micro),
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
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Icon(
                          Icons.flash_on_rounded,
                          color: colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quiz Duel',
                              style: typography.title2.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Answer quickly and correctly to earn bonus points.',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => QuizDuelLeaderboardSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: eloTier.color.withAlpha(isDark ? 35 : 20),
                            borderRadius: BorderRadius.circular(AppRadius.micro),
                            border: Border.all(
                              color: eloTier.color.withAlpha(100),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${eloTier.label} • $userElo ELO',
                                style: typography.caption.bold.copyWith(
                                  color: eloTier.color,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.leaderboard_rounded,
                                size: 12,
                                color: eloTier.color,
                              ),
                            ],
                          ),
                        ),
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
                                    color: colors.primary.withValues(
                                      alpha:
                                          (0.12 -
                                                  (pulseController.value *
                                                      0.08))
                                              .clamp(0.0, 1.0),
                                    ),
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha:
                                            (0.4 +
                                                    (pulseController.value *
                                                        0.4))
                                                .clamp(0.0, 1.0),
                                      ),
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
                                            color: colors.black.withValues(
                                              alpha: isDark ? 0.4 : 0.15,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.radar_rounded,
                                          color: colors.white,
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
                              'Looking for a classmate… (${((searchSeconds.value ~/ 60) + 1).toString().padLeft(2, '0')}:${(searchSeconds.value % 60).toString().padLeft(2, '0')} of 02:00)',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Searching classmates studying ${selectedSubject.value} ($resolvedExamBoard)\nIf nobody joins within 2 minutes, you will practice with AI',
                              textAlign: TextAlign.center,
                              style: typography.body.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      text: 'Practice with AI now',
                      onPressed: () async {
                        AppFeedback.light();
                        await context
                            .read<QuizDuelCubit>()
                            .matchWithAiImmediately();
                      },
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      text: 'Cancel search',
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        isSearching.value = false;
                        await context.read<QuizDuelCubit>().leaveMatch();
                      },
                    ),
                  ] else ...[
                    // Subject Selector
                    Text(
                      'Subject',
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
                          selectedColor: colors.primary.withValues(alpha: 0.2),
                          backgroundColor: colors.surfaceSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? colors.primary.withValues(alpha: 0.4)
                                  : colors.surfaceBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          labelStyle: context.typography.body.regular.copyWith(
                            color: isSelected
                                ? colors.primary
                                : colors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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

                    // Question Count Selector
                    Text(
                      'Questions',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: questionCounts.map((count) {
                        final isSelected = selectedQuestionCount.value == count;
                        return ChoiceChip(
                          label: Text(
                            '$count questions${count == 10 ? ' (default)' : ''}',
                          ),
                          selected: isSelected,
                          selectedColor: colors.primary.withValues(alpha: 0.2),
                          backgroundColor: colors.surfaceSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? colors.primary.withValues(alpha: 0.4)
                                  : colors.surfaceBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          labelStyle: context.typography.body.regular.copyWith(
                            color: isSelected
                                ? colors.primary
                                : colors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              AppFeedback.selection();
                              selectedQuestionCount.value = count;
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Match Rule Highlights
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: colors.surfaceBorder.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${selectedQuestionCount.value} questions • 15 seconds each • Answer faster to earn more points',
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
                      text: 'Find a classmate',
                      onPressed: startMatchmaking,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      text: 'Invite via Link',
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        AppFeedback.selection();
                        unawaited(
                          Clipboard.setData(
                            ClipboardData(
                              text: 'https://kortex.app/duel/join?subject=${selectedSubject.value}',
                            ),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied ${selectedSubject.value} duel challenge link! Share with a friend.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
