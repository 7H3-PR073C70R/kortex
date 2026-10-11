import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_forum_question_selector_sheet.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Coordinator for preparing and publishing forum questions from quiz results.
abstract final class QuizForumPostCoordinator {
  static void handleAskClassForHelp({
    required BuildContext context,
    required List<QuizQuestionEntity> questions,
    required List<QuizQuestionEntity> missedQuestions,
    required String? courseCode,
    CommunityHubBloc? communityHubBloc,
  }) {
    unawaited(HapticFeedback.lightImpact());
    final allQuestions = questions.isNotEmpty ? questions : missedQuestions;

    if (allQuestions.isEmpty) {
      context.showSnackBar(
        message: 'No quiz questions available to discuss.',
      );
      return;
    }

    if (allQuestions.length == 1) {
      openCreatePostForQuestions(
        context: context,
        questions: [allQuestions.first],
        courseCode: courseCode,
        communityHubBloc: communityHubBloc,
      );
      return;
    }

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 600,
        builder: (sheetCtx) {
          return QuizForumQuestionSelectorSheet(
            questions: allQuestions,
            missedQuestions: missedQuestions,
            onConfirm: (selected) {
              Navigator.of(sheetCtx).pop();
              openCreatePostForQuestions(
                context: context,
                questions: selected,
                courseCode: courseCode,
                communityHubBloc: communityHubBloc,
              );
            },
          );
        },
      ),
    );
  }

  static void openCreatePostForQuestions({
    required BuildContext context,
    required List<QuizQuestionEntity> questions,
    required String? courseCode,
    CommunityHubBloc? communityHubBloc,
  }) {
    if (questions.isEmpty) return;

    final isSingle = questions.length == 1;
    final primaryQuestion = questions.first;
    final topicTag = primaryQuestion.subTopic.trim().isNotEmpty
        ? primaryQuestion.subTopic.trim()
        : (courseCode ?? 'Quiz review');

    final contentBuf = StringBuffer();

    if (isSingle) {
      final q = primaryQuestion;
      contentBuf.writeln(q.prompt.replaceAll('**', ''));
      if (q.options.isNotEmpty) {
        contentBuf
          ..writeln()
          ..writeln('Options:');
        for (final opt in q.options) {
          contentBuf.writeln('• ${opt.replaceAll('**', '')}');
        }
      }
      contentBuf
        ..writeln()
        ..writeln(
          'Your Answer: ${q.userSelectedAnswer ?? 'Unanswered'}',
        )
        ..writeln('Correct Answer: ${q.correctAnswer}');
      if (q.explanation.isNotEmpty) {
        contentBuf
          ..writeln()
          ..writeln(
            'Explanation:\n${q.explanation.replaceAll('**', '')}',
          );
      }
      contentBuf
        ..writeln()
        ..writeln(
          'I missed this one during practice. Can someone break down how to approach it?',
        );
    } else {
      contentBuf.writeln(
        'I am reviewing my practice session and would appreciate help breaking down these questions:\n',
      );
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        contentBuf
          ..writeln('### Question ${i + 1}')
          ..writeln(q.prompt.replaceAll('**', ''));
        if (q.options.isNotEmpty) {
          contentBuf
            ..writeln()
            ..writeln('Options:');
          for (final opt in q.options) {
            contentBuf.writeln('• ${opt.replaceAll('**', '')}');
          }
        }
        contentBuf
          ..writeln()
          ..writeln('• Your Answer: ${q.userSelectedAnswer ?? 'Unanswered'}')
          ..writeln('• Correct Answer: ${q.correctAnswer}');
        if (q.explanation.isNotEmpty) {
          contentBuf.writeln(
            '• Explanation: ${q.explanation.replaceAll('**', '')}',
          );
        }
        if (i < questions.length - 1) {
          contentBuf.writeln('\n---\n');
        }
      }
      contentBuf.writeln(
        '\nCan someone explain the concepts and how to solve these?',
      );
    }

    final initialTitle = isSingle
        ? '[$topicTag] Question discussion'
        : '[$topicTag] Review: ${questions.length} Quiz Questions';

    final firstLatex = questions
        .firstWhere(
          (q) => q.latexFormula != null && q.latexFormula!.isNotEmpty,
          orElse: () => primaryQuestion,
        )
        .latexFormula;

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: courseCode,
        initialTitle: initialTitle,
        initialContent: contentBuf.toString().trim(),
        initialLatex: firstLatex,
        initialSyllabusTag: topicTag,
        initialIsQuestion: true,
        contextBadge: isSingle
            ? 'Practice question • $topicTag'
            : '${questions.length} Practice questions • $topicTag',
        onSubmit: ({
          required title,
          required content,
          required track,
          latexContent,
          isQuestion = true,
          syllabusTag = 'General',
          isAnonymous = true,
        }) {
          final effectiveCommunityHubBloc = communityHubBloc ??
              (locator.isRegistered<CommunityHubBloc>()
                  ? locator<CommunityHubBloc>()
                  : null);
          if (effectiveCommunityHubBloc != null) {
            final effectiveTag = primaryQuestion.subTopic.trim().isNotEmpty
                ? primaryQuestion.subTopic.trim()
                : syllabusTag;
            effectiveCommunityHubBloc.add(
              CreateForumPostEvent(
                title: title,
                content: content,
                track: track,
                latexContent: latexContent,
                isQuestion: true,
                syllabusTag: effectiveTag,
                isAnonymous: isAnonymous,
              ),
            );
          }
          context.showSnackBar(
            message: 'Posted to your class. Replies show up in the feed.',
            type: SnackBarType.success,
          );
        },
      ),
    );
  }
}
