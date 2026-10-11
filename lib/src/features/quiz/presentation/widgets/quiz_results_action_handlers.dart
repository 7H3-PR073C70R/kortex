import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/domain/services/assessment_orchestrator_service.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_forum_post_coordinator.dart';
import 'package:kortex/src/shared/widgets/gratification_celebration_overlay.dart';

/// Encapsulated actions, evaluation utilities, and navigators for QuizResultsPage.
abstract final class QuizResultsActionHandlers {
  static bool isQuestionCorrect(QuizQuestionEntity q) {
    if (q.isCorrect) return true;
    if (q.userSelectedAnswer == null || q.userSelectedAnswer!.trim().isEmpty) {
      return false;
    }
    final cleanCorrect = QuizContentSanitizer.cleanOptionText(
      q.correctAnswer,
    ).trim().toLowerCase();
    final cleanSelected = QuizContentSanitizer.cleanOptionText(
      q.userSelectedAnswer!,
    ).trim().toLowerCase();
    return cleanCorrect == cleanSelected ||
        q.userSelectedAnswer!.trim().toLowerCase() ==
            q.correctAnswer.trim().toLowerCase();
  }

  static List<QuizQuestionEntity> missedQuestions(
    List<QuizQuestionEntity> questions,
  ) =>
      questions.where((q) => !isQuestionCorrect(q)).toList();

  static int mistakeCount({
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
  }) {
    if (questions.isNotEmpty) return missedQuestions(questions).length;
    final missed = result.totalQuestions - result.correctAnswers;
    return missed < 0 ? 0 : missed;
  }

  static int xpEarned({
    required QuizResultEntity result,
    required AssessmentMode mode,
    required int currentTier,
    required int speedBonusXp,
  }) {
    if (mode == AssessmentMode.millionaireMode) {
      return (currentTier * 100) + speedBonusXp;
    }
    return result.correctAnswers * 15;
  }

  static bool isBigWin({
    required int score,
    required AssessmentMode mode,
    required int currentTier,
    required bool isWalkedAway,
  }) {
    if (mode == AssessmentMode.millionaireMode) {
      return currentTier >= 12 || isWalkedAway;
    }
    return score >= 90;
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return '${rest}s';
    if (rest == 0) return '${minutes}m';
    return '${minutes}m ${rest}s';
  }

  static void processPostCompletionTelemetry({
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    required String? courseCode,
    required String? activeTrack,
    AssessmentOrchestratorService? orchestrator,
    DashboardBloc? dashboardBloc,
    CramPlannerCubit? plannerCubit,
  }) {
    final effectiveOrchestrator = orchestrator ??
        (locator.isRegistered<AssessmentOrchestratorService>()
            ? locator<AssessmentOrchestratorService>()
            : null);
    if (effectiveOrchestrator != null) {
      try {
        final effectiveSubject = courseCode?.trim().isNotEmpty == true
            ? courseCode!.trim()
            : (result.quizTitle.contains('(')
                ? result.quizTitle.split('(').first.trim()
                : result.quizTitle.trim());
        final cleanSubject = effectiveSubject
            .replaceAll(
              RegExp(
                r'\s+(Diagnostic Quiz|Practice Quiz|Practice Test|Mock Exam|Quiz|Exam)\b',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        final subjectToRecord =
            cleanSubject.isNotEmpty ? cleanSubject : effectiveSubject;

        unawaited(
          effectiveOrchestrator.processQuizCompletion(
            scorePercent: result.scorePercent.toDouble(),
            totalQuestions: result.totalQuestions,
            correctAnswers: result.correctAnswers,
            questions: questions,
            userAnswers: questions.map((q) => q.isCorrect ? 1 : 0).toList(),
            courseCode: subjectToRecord,
            explicitTrack: activeTrack ?? subjectToRecord,
          ),
        );
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    final effectiveDashboardBloc = dashboardBloc ??
        (locator.isRegistered<DashboardBloc>()
            ? locator<DashboardBloc>()
            : null);
    if (effectiveDashboardBloc != null) {
      try {
        effectiveDashboardBloc.add(const DashboardRefreshed());
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    final effectivePlannerCubit = plannerCubit ??
        (locator.isRegistered<CramPlannerCubit>()
            ? locator<CramPlannerCubit>()
            : null);
    if (effectivePlannerCubit != null) {
      try {
        final exams = effectivePlannerCubit.state.activeExams;
        final matched = exams.where((e) {
          return (courseCode != null &&
                  courseCode.isNotEmpty &&
                  (e.subjectTrack
                          .toLowerCase()
                          .contains(courseCode.toLowerCase()) ||
                      e.examName
                          .toLowerCase()
                          .contains(courseCode.toLowerCase()))) ||
              result.quizTitle
                  .toLowerCase()
                  .contains(e.examName.toLowerCase()) ||
              e.examName
                  .toLowerCase()
                  .contains(result.quizTitle.toLowerCase());
        }).firstOrNull;
        if (matched != null) {
          unawaited(
            effectivePlannerCubit.completeAssessment(
              examId: matched.id,
              scorePercent: (result.scorePercent / 100.0).clamp(0.0, 1.0),
            ),
          );
        }
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }
  }

  static void showCelebrationDialog({
    required BuildContext context,
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    required AssessmentMode assessmentMode,
    required int currentTier,
    required int speedBonusXp,
    required VoidCallback onTryAgain,
    required void Function(List<QuizQuestionEntity> mistakes) onReviewMistakes,
  }) {
    final isMillionaire = assessmentMode == AssessmentMode.millionaireMode;
    final isMockExam = assessmentMode == AssessmentMode.examSimulationMode;
    final score = result.scorePercent;

    final String title;
    final String subtitle;
    final String emoji;
    final String? badge;

    if (isMillionaire) {
      emoji = '👑';
      title = currentTier >= 12 ? 'Top of the Ladder!' : 'Progress Banked!';
      subtitle =
          'You conquered $currentTier tiers and banked ${(currentTier * 100) + speedBonusXp} XP!';
      badge = '👑 Millionaire Scholar';
    } else if (isMockExam) {
      emoji = score >= 80 ? '🎓' : (score >= 50 ? '🏛️' : '📝');
      title = score >= 90
          ? 'Exam Mastery Achieved!'
          : (score >= 70
              ? 'Mock Exam Completed!'
              : (score >= 50
                  ? 'Exam Simulation Done!'
                  : 'Mock Exam Finished!'));
      subtitle = score >= 70
          ? 'You completed the full exam simulation with $score% accuracy. Exam readiness locked in!'
          : 'Completed the full exam simulation. Reviewing your missed questions now will solidify your readiness.';
      badge = '🎓 Exam Simulation Milestone';
    } else {
      emoji = score >= 90 ? '🌟' : (score >= 70 ? '⚡' : '💪');
      title = score >= 90
          ? 'Flawless Knowledge!'
          : (score >= 70
              ? 'Quiz Completed!'
              : (score >= 50 ? 'Milestone Complete!' : 'Practice Finished!'));
      subtitle = score >= 70
          ? 'You answered ${result.correctAnswers}/${result.totalQuestions} questions correctly! Synaptic recall sharpened.'
          : 'Consistency is what builds genius. Review your answers below to convert every mistake into mastery.';
      badge = '⚡ Active Practice Milestone';
    }

    final xp = isMillionaire
        ? (currentTier * 100) + speedBonusXp
        : (result.correctAnswers * 15);

    final mistakes = missedQuestions(questions);

    unawaited(
      GratificationCelebrationOverlay.show(
        context,
        title: title,
        subtitle: subtitle,
        primaryStatLabel: 'Score',
        primaryStatValue: '$score%',
        secondaryStatLabel: 'Correct',
        secondaryStatValue: '${result.correctAnswers}/${result.totalQuestions}',
        tertiaryStatLabel: 'XP Earned',
        tertiaryStatValue: '+$xp',
        xpEarned: xp,
        motivationalBadge: badge,
        buttonText: 'See Full Breakdown',
        secondaryButtonText:
            mistakes.isNotEmpty ? 'Review Mistakes' : 'Practice Again',
        onSecondaryAction: () {
          if (mistakes.isNotEmpty) {
            onReviewMistakes(mistakes);
          } else {
            onTryAgain();
          }
        },
        emoji: emoji,
      ),
    );
  }

  static void openMistakeReview({
    required BuildContext context,
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questionsToReview,
    required String? courseId,
    required String? courseCode,
  }) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      context.router.push(
        QuizWorkspaceRoute(
          deckId: 'review-${result.id}',
          deckTitle: 'Review: ${result.quizTitle}',
          initialQuestions: questionsToReview,
          courseId: courseId,
          courseCode: courseCode,
          reviewMode: true,
        ),
      ),
    );
  }

  static void handleTryAgain({
    required BuildContext context,
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    required String? courseId,
    required String? courseCode,
    required AssessmentMode assessmentMode,
  }) {
    unawaited(HapticFeedback.lightImpact());
    final fresh = questions
        .map(
          (q) => q.copyWith(
            isAnswered: false,
            isCorrect: false,
            clearUserSelectedAnswer: true,
          ),
        )
        .toList();
    unawaited(
      context.router.push(
        QuizWorkspaceRoute(
          deckId: 'retry-${result.id}',
          deckTitle: result.quizTitle,
          initialQuestions: fresh,
          courseId: courseId,
          courseCode: courseCode,
          assessmentMode: assessmentMode,
        ),
      ),
    );
  }

  static Future<void> handleShareResult({
    required BuildContext context,
    required QuizResultEntity result,
    LinkSharingService? linkSharingService,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final effectiveSharing = linkSharingService ??
        (locator.isRegistered<LinkSharingService>()
            ? locator<LinkSharingService>()
            : null);
    if (effectiveSharing != null) {
      final deckId = result.id.isNotEmpty ? result.id : 'general-quiz';
      await effectiveSharing.shareQuizDuel(
        duelId: 'quiz-score-${result.id}',
        deckId: deckId,
        deckTitle: result.quizTitle,
      );
    }
  }

  static void handleAskClassForHelp({
    required BuildContext context,
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    required String? courseCode,
    CommunityHubBloc? communityHubBloc,
  }) {
    QuizForumPostCoordinator.handleAskClassForHelp(
      context: context,
      questions: questions,
      missedQuestions: missedQuestions(questions),
      courseCode: courseCode,
      communityHubBloc: communityHubBloc,
    );
  }

  static Future<void> handlePracticeWeakFlashcards({
    required BuildContext context,
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    required String? courseId,
    required String? courseCode,
    SubscriptionGuard? subscriptionGuard,
    ConvertFailedQuizToDeckUseCase? convertFailedQuizToDeckUseCase,
    DecksRepository? decksRepository,
    DecksBloc? decksBloc,
    DashboardBloc? dashboardBloc,
    CramPlannerCubit? cramPlannerCubit,
  }) async {
    unawaited(HapticFeedback.lightImpact());

    final guard = subscriptionGuard ??
        (locator.isRegistered<SubscriptionGuard>()
            ? locator<SubscriptionGuard>()
            : null);
    if (guard != null) {
      final isPro = await guard.requirePro(
        context,
        featureName: 'Quiz Weakness Flashcards',
      );
      if (!isPro || !context.mounted) return;
    }

    final incorrectQuestions = missedQuestions(questions);
    final questionsToUse =
        incorrectQuestions.isNotEmpty ? incorrectQuestions : questions;

    if (questionsToUse.isEmpty && result.weaknesses.isEmpty) {
      context.showSnackBar(
        message: 'There are no questions to turn into flashcards yet.',
      );
      return;
    }

    var resolvedCourseId = courseId?.trim();
    var resolvedCourseCode = courseCode?.trim();

    final effectiveDecksBloc = decksBloc ??
        (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null);

    if ((resolvedCourseId == null || resolvedCourseId.isEmpty) &&
        (resolvedCourseCode == null || resolvedCourseCode.isEmpty)) {
      if (effectiveDecksBloc != null) {
        final allDecks = effectiveDecksBloc.state.allDecks;
        for (final d in allDecks) {
          if (d.courseCode != null &&
              d.courseCode!.isNotEmpty &&
              result.quizTitle.toLowerCase().contains(
                    d.courseCode!.toLowerCase(),
                  )) {
            resolvedCourseId = d.courseId;
            resolvedCourseCode = d.courseCode;
            break;
          }
        }
      }
    }

    final convertUseCase = convertFailedQuizToDeckUseCase ??
        (locator.isRegistered<ConvertFailedQuizToDeckUseCase>()
            ? locator<ConvertFailedQuizToDeckUseCase>()
            : ConvertFailedQuizToDeckUseCase(
                decksRepository ?? locator<DecksRepository>(),
              ));

    final conversionResult = await convertUseCase(
      result: result,
      questions: questions,
      courseId: resolvedCourseId,
      courseCode: resolvedCourseCode,
    );

    conversionResult.fold(
      (failure) {
        if (context.mounted) {
          context.showSnackBar(
            message: failure.message ?? 'The flashcards could not be created.',
            type: SnackBarType.error,
          );
        }
      },
      (deck) {
        if (effectiveDecksBloc != null) {
          effectiveDecksBloc.add(const DecksRefreshed());
        }
        final effectiveDashboardBloc = dashboardBloc ??
            (locator.isRegistered<DashboardBloc>()
                ? locator<DashboardBloc>()
                : null);
        if (effectiveDashboardBloc != null) {
          effectiveDashboardBloc.add(const DashboardRefreshed());
        }

        if (context.mounted) {
          context.showSnackBar(
            message:
                'Your missed questions are now ${deck.totalCards} flashcards.',
            type: SnackBarType.success,
          );

          int? daysUntilExam;
          final effectivePlannerCubit = cramPlannerCubit ??
              (locator.isRegistered<CramPlannerCubit>()
                  ? locator<CramPlannerCubit>()
                  : null);
          if (effectivePlannerCubit != null) {
            final exams = effectivePlannerCubit.state.activeExams;
            final matched = exams.where((e) =>
                e.daysRemaining > 0 &&
                e.daysRemaining <= 14 &&
                (resolvedCourseCode != null &&
                    resolvedCourseCode.isNotEmpty &&
                    (e.subjectTrack.toLowerCase() ==
                            resolvedCourseCode.toLowerCase() ||
                        e.examName.toLowerCase().contains(
                            resolvedCourseCode.toLowerCase()))),
            ).firstOrNull ?? exams.where((e) => e.daysRemaining > 0 && e.daysRemaining <= 14).firstOrNull;
            if (matched != null) {
              daysUntilExam = matched.daysRemaining;
            }
          }

          final targetDeckId = (daysUntilExam != null && daysUntilExam > 0)
              ? 'cram:$daysUntilExam:${deck.id}'
              : deck.id;

          unawaited(
            context.router.replace(
              StudySessionRoute(deckId: targetDeckId),
            ),
          );
        }
      },
    );
  }
}
