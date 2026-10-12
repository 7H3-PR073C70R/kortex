import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_answer_matcher.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_palette_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

abstract final class QuizWorkspaceDialogs {
  /// Opens the class discussion sheet pre-filled with this question.
  static void askClassAbout(
    BuildContext context,
    QuizQuestionEntity question,
    String? courseCode,
    String? deckTitle,
  ) {
    unawaited(HapticFeedback.lightImpact());
    final topicTag = question.subTopic.trim().isNotEmpty
        ? question.subTopic.trim()
        : (courseCode ?? 'Quiz question');

    final buffer = StringBuffer(question.prompt.replaceAll('**', ''));
    if (question.options.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('Options:');
      for (final opt in question.options) {
        buffer.writeln('• ${opt.replaceAll('**', '')}');
      }
    }
    buffer
      ..writeln()
      ..writeln('Correct answer: ${question.correctAnswer}');
    if (question.explanation.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Explanation:')
        ..writeln(question.explanation.replaceAll('**', ''));
    }
    buffer
      ..writeln()
      ..writeln('Would like a second explanation or another method.');

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: courseCode ?? deckTitle,
        initialTitle: '[$topicTag] Question discussion',
        initialContent: buffer.toString().trim(),
        initialLatex: question.latexFormula,
        initialSyllabusTag: topicTag,
        initialIsQuestion: true,
        contextBadge: 'Practice question • $topicTag',
        onSubmit:
            ({
              required title,
              required content,
              required track,
              latexContent,
              isQuestion = true,
              syllabusTag = 'Quiz question',
              isAnonymous = false,
            }) {
              final communityBloc = context.read<CommunityHubBloc?>();
              if (communityBloc != null) {
                communityBloc.add(
                  CreateForumPostEvent(
                    title: title,
                    content: content,
                    track: track,
                    latexContent: latexContent,
                    isQuestion: true,
                    syllabusTag: syllabusTag,
                    isAnonymous: isAnonymous,
                  ),
                );
                context.showSnackBar(message: 'Posted to your class.');
              }
            },
      ),
    );
  }

  static void confirmExit(BuildContext context, QuizSessionState state) {
    if (state.status != QuizSessionStatus.inProgress &&
        state.status != QuizSessionStatus.questionAnswered) {
      Navigator.of(context).pop();
      return;
    }
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(context.l10n.quizLeaveDialogTitle),
          content: Text(
            'You have answered ${state.answeredCount} of ${state.totalQuestions}.\n\n'
            'If you come back to this deck later you can start again in a minute.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.quizKeepGoing),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.white,
              ),
              child: Text(isExamSession(state) ? 'Leave exam' : 'Leave quiz'),
            ),
          ],
        ),
      ),
    );
  }

  static void confirmSubmit(BuildContext context, QuizSessionState state) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(context.l10n.quizFinishDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.quizFinishDialogSub),
              const SizedBox(height: 14),
              Text(
                '• Answered: ${state.answeredCount} of ${state.totalQuestions}',
              ),
              Text('• Left blank: ${state.unansweredCount}'),
              if (state.flaggedCount > 0)
                Text('• Flagged to look at again: ${state.flaggedCount}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.quizGoBack),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                unawaited(context.read<QuizSessionCubit>().submitQuiz());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.white,
              ),
              child: Text(context.l10n.quizSeeResults),
            ),
          ],
        ),
      ),
    );
  }

  /// Question navigator: counts first, the grid next, one way out.
  static void showQuestionPalette({
    required BuildContext context,
    required QuizSessionCubit cubit,
    required QuizSessionState state,
    required bool reviewMode,
  }) {
    unawaited(
      AppAdaptiveSheet.showSideDrawer<void>(
        context: context,
        width: 440,
        builder: (sheetCtx) => QuestionPaletteSheet(
          state: state,
          onJump: (index) {
            Navigator.of(sheetCtx).pop();
            cubit.jumpToQuestion(index);
          },
          onSubmit: reviewMode
              ? null
              : () {
                  Navigator.of(sheetCtx).pop();
                  confirmSubmit(context, state);
                },
        ),
      ),
    );
  }
}
