import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_answer_matcher.dart';

class QuizWorkspaceOptionsList extends StatelessWidget {
  const QuizWorkspaceOptionsList({
    required this.question,
    required this.state,
    required this.reviewMode,
    required this.reduceMotion,
    super.key,
  });

  final QuizQuestionEntity question;
  final QuizSessionState state;
  final bool reviewMode;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final isPractice = state.assessmentMode == AssessmentMode.discoveryMode;
    final isMillionaire = state.assessmentMode == AssessmentMode.millionaireMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: question.options.asMap().entries.map((entry) {
        final idx = entry.key;
        final opt = entry.value;

        if (isMillionaire && state.isOptionEliminated(idx)) {
          return const SizedBox.shrink();
        }

        final userPick = question.userSelectedAnswer ??
            (isPractice ? state.pendingAnswer : null);
        final isOptSelected = userPick != null &&
            userPick.trim().isNotEmpty &&
            (userPick == opt || isSameAnswer(userPick, opt));
        final isCorrectOption = isSameAnswer(opt, question.correctAnswer);
        final isAnsweredState = reviewMode || question.isAnswered;

        final optionTrailingLabel = isAnsweredState
            ? (isOptSelected
                ? 'Your Answer'
                : (isCorrectOption ? 'Correct Answer' : null))
            : null;

        return QuizStaggeredFade(
          index: 3 + idx,
          distance: 10,
          reduceMotion: reduceMotion,
          child: McqOptionCard(
            optionText: opt,
            index: idx,
            reduceMotion: reduceMotion,
            trailingLabel: optionTrailingLabel,
            state: McqOptionCard.resolveState(
              isSelected: isOptSelected,
              isAnswered: isAnsweredState,
              isCorrect: isCorrectOption,
            ),
            onTap: () {
              if (reviewMode) return;
              context.read<QuizSessionCubit>().selectOption(opt);
            },
          ),
        );
      }).toList(),
    );
  }
}
