import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_view.dart';

@RoutePage()
class QuizWorkspacePage extends StatelessWidget {
  const QuizWorkspacePage({
    @PathParam('deckId') this.deckId = 'deck-default',
    @QueryParam('title') this.deckTitle,
    this.subject,
    this.durationMinutes,
    this.initialQuestions,
    this.courseId,
    this.courseCode,
    this.assessmentMode = AssessmentMode.discoveryMode,
    this.reviewMode = false,
    this.quizSessionCubit,
    this.decksBloc,
    super.key,
  });

  final String deckId;
  final String? deckTitle;
  final String? subject;
  final int? durationMinutes;
  final List<QuizQuestionEntity>? initialQuestions;
  final String? courseId;
  final String? courseCode;
  final AssessmentMode assessmentMode;

  /// Read-only walkthrough of already answered questions.
  /// Answers and verdicts stay exactly as they were during the session.
  final bool reviewMode;

  final QuizSessionCubit? quizSessionCubit;
  final DecksBloc? decksBloc;

  @override
  Widget build(BuildContext context) {
    final view = QuizWorkspaceView(
      deckId: deckId,
      deckTitle: deckTitle ?? subject,
      courseId: courseId,
      courseCode: courseCode ?? subject,
      reviewMode: reviewMode,
      decksBloc: decksBloc,
    );

    try {
      final existing = context.read<QuizSessionCubit>();
      if (!reviewMode &&
          existing.state.status == QuizSessionStatus.inProgress &&
          existing.state.questions.isNotEmpty) {
        return view;
      }
    } on Object catch (e, st) {
      // No ancestor QuizSessionCubit found, proceed to create one.
      AppLogger.debug('[QuizWorkspacePage] No ancestor QuizSessionCubit found: $e', error: e, stackTrace: st);
    }

    final cubit = quizSessionCubit ?? locator<QuizSessionCubit>();
    if (reviewMode) {
      cubit.startReview(
        title: deckTitle ?? 'Review your answers',
        questions: initialQuestions ?? const [],
      );
    } else if (cubit.state.status == QuizSessionStatus.inProgress &&
        cubit.state.questions.isNotEmpty) {
      // In-progress session already active (e.g. preserved or restored)
    } else if (QuizSessionCubit.hasActiveRestorableSession &&
        (initialQuestions == null || initialQuestions!.isEmpty)) {
      unawaited(cubit.restoreActiveSession());
    } else if (initialQuestions != null && initialQuestions!.isNotEmpty) {
      if (assessmentMode == AssessmentMode.millionaireMode) {
        cubit.startMillionaireQuiz(
          title: deckTitle ?? subject ?? 'Millionaire Challenge',
          questions: initialQuestions!,
        );
      } else {
        cubit.startQuizFromPastQuestions(
          title: deckTitle ?? subject ?? 'CBT Practice Test',
          questions: initialQuestions!,
          durationMinutes: durationMinutes ?? 30,
          assessmentMode: assessmentMode,
        );
      }
    } else {
      unawaited(
        cubit.startQuizFromDeck(
          deckId: deckId,
          deckTitle: deckTitle ?? subject,
          assessmentMode: assessmentMode,
        ),
      );
    }

    return BlocProvider<QuizSessionCubit>.value(
      value: cubit,
      child: view,
    );
  }
}
