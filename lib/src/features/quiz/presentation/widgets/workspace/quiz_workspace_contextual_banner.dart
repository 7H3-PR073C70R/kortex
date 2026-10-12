import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';

/// Contextual banner slot for millionaire challenge state notices.
class QuizWorkspaceContextualBanner extends StatelessWidget {
  const QuizWorkspaceContextualBanner({
    required this.state,
    super.key,
  });

  final QuizSessionState state;

  @override
  Widget build(BuildContext context) {
    if (state.assessmentMode != AssessmentMode.millionaireMode) {
      return const SizedBox.shrink();
    }
    final cubit = context.read<QuizSessionCubit>();

    if (state.isSoftFailed) {
      return QuizInlineBanner(
        icon: Icons.verified_user_rounded,
        tone: QuizBannerTone.warning,
        title: 'Tier ${state.bankedTier} is secured',
        message: '+${state.bankedTierPrizeXp} XP is banked and stays yours.',
        actionLabel: 'Collect XP',
        onAction: () => unawaited(cubit.submitQuiz()),
      );
    }
    if (state.isSecondChanceActive) {
      return QuizInlineBanner(
        icon: Icons.shield_outlined,
        tone: QuizBannerTone.success,
        title: 'Second chance open',
        message: 'Try another option. Your banked progress is not at risk.',
        actionLabel: 'Try again',
        onAction: cubit.useSecondChance,
      );
    }
    final clue = state.activeClueText;
    if (clue != null) {
      return QuizInlineBanner(
        icon: Icons.auto_awesome_rounded,
        tone: QuizBannerTone.tutor,
        title: 'Tutor clue',
        message: clue,
      );
    }
    return const SizedBox.shrink();
  }
}
