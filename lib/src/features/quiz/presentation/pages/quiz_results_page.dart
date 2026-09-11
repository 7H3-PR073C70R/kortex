import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({
    required this.result,
    this.questions = const [],
    this.courseId,
    this.courseCode,
    super.key,
  });

  final QuizResultEntity result;
  final List<QuizQuestionEntity> questions;
  final String? courseId;
  final String? courseCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final score = result.scorePercent;
    final isPassed = score >= 70;
    final gradeColor = isPassed ? colors.success : colors.warning;

    return Scaffold(
      backgroundColor: colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          result.quizTitle,
          style: typography.title3.bold.copyWith(
            color: colors.white,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // 1. Grade Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradeColor.withValues(alpha: 0.2),
                  colors.surfacePrimary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: gradeColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isPassed
                      ? Icons.emoji_events_rounded
                      : Icons.insights_rounded,
                  size: 54,
                  color: gradeColor,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.quizScoreLabel(score),
                  style: typography.largeTitle.bold.copyWith(
                    color: colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.correctAnswers} of ${result.totalQuestions} '
                  'questions correct',
                  style: typography.body.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Weakness Breakdown Section Header
          Text(
            l10n.quizTopicWeakness,
            style: typography.title3.bold.copyWith(
              color: colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // 3. Topic Weakness Tiles
          if (result.weaknesses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Comprehensive mastery across all topics!',
                style: typography.body.regular.copyWith(
                  color: colors.success,
                ),
              ),
            )
          else
            ...result.weaknesses.map((weakness) {
              final acc = (weakness.accuracy * 100).toInt();
              final isWeak = weakness.isWeak;
              final badgeColor = isWeak ? colors.error : colors.success;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surfacePrimary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWeak
                        ? colors.error.withValues(alpha: 0.3)
                        : colors.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weakness.subTopic,
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${weakness.correctCount} / ${weakness.totalQuestions} Correct',
                            style: typography.caption.regular.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '$acc%',
                        style: typography.caption.bold.copyWith(
                          color: badgeColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          // 4. Diagnostic Mistake Autopsy (Cognitive Learning Science)
          if (!isPassed && result.totalQuestions > result.correctAnswers) ...[
            const SizedBox(height: 24),
            Text(
              'Diagnostic Mistake Autopsy',
              style: typography.title3.bold.copyWith(
                color: colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cognitive breakdown to target root causes behind missed answers:',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: colors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conceptual Reinforcement Needed',
                          style: typography.subhead.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${result.totalQuestions - result.correctAnswers} missed questions converted into targeted flashcards below.',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          border: Border(
            top: BorderSide(
              color: colors.surfaceBorder.withAlpha(isDark ? 60 : 120),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.style_rounded, size: 20, color: colors.white),
                  label: Text(
                    l10n.practiceWeakCards,
                    style: typography.callout.bold.copyWith(color: colors.white),
                  ),
                  onPressed: () => _handlePracticeWeakFlashcards(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.help_outline_rounded, size: 18, color: colors.warning),
                  label: Text(
                    'Ask Pod for Help (+100 XP Bounty)',
                    style: typography.caption.bold.copyWith(color: colors.warning),
                  ),
                  onPressed: () => _handleAskPodForHelp(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.warning.withAlpha(isDark ? 100 : 70)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAskPodForHelp(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final incorrectQuestions = questions.where((q) => !q.isCorrect).toList();
    final questionToAsk = incorrectQuestions.isNotEmpty ? incorrectQuestions.first : questions.firstOrNull;

    final topicTag = questionToAsk?.subTopic.trim().isNotEmpty == true
        ? questionToAsk!.subTopic.trim()
        : (courseCode ?? 'Quiz Review');
    final firstLine = questionToAsk?.prompt.split('\n').first.trim() ?? 'Quiz Question';
    final shortPrompt = firstLine.length > 55 ? '${firstLine.substring(0, 52)}...' : firstLine;

    final contentBuf = StringBuffer();
    if (questionToAsk != null) {
      contentBuf.writeln(questionToAsk.prompt);
      if (questionToAsk.options.isNotEmpty) {
        contentBuf.writeln('\n**Options:**');
        for (final opt in questionToAsk.options) {
          contentBuf.writeln('• $opt');
        }
      }
      contentBuf
        ..writeln(
          '\nYour Answer: ${questionToAsk.userSelectedAnswer ?? 'Unanswered'}',
        )
        ..writeln('Correct Answer: ${questionToAsk.correctAnswer}');
      if (questionToAsk.explanation.isNotEmpty) {
        contentBuf.writeln('\n**Explanation:**\n${questionToAsk.explanation}');
      }
      contentBuf.writeln(
        '\n💡 I missed this question during practice. Can someone in the cohort break down how to approach it?',
      );
    }

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: courseCode,
        initialTitle: '[$topicTag] Need help: $shortPrompt',
        initialContent: contentBuf.toString().trim(),
        initialLatex: questionToAsk?.latexFormula,
        initialSyllabusTag: topicTag,
        initialIsQuestion: true,
        contextBadge: 'Quiz Review Bounty • $topicTag',
        onSubmit: ({
          required title,
          required content,
          required track,
          latexContent,
          isQuestion = true,
          syllabusTag = 'General',
          isAnonymous = true,
        }) {
          if (locator.isRegistered<CommunityHubBloc>()) {
            final effectiveTag = questionToAsk?.subTopic ?? syllabusTag;
            locator<CommunityHubBloc>().add(
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
            message: 'Question bounty posted to class cohort! 🎯 (+100 XP Bounty)',
            type: SnackBarType.success,
          );
        },
      ),
    );
  }

  Future<void> _handlePracticeWeakFlashcards(BuildContext context) async {
    unawaited(HapticFeedback.lightImpact());

    if (locator.isRegistered<SubscriptionGuard>()) {
      final isPro = await locator<SubscriptionGuard>().requirePro(
        context,
        featureName: 'AI Exam Weakness Remediation',
      );
      if (!isPro || !context.mounted) return;
    }

    // Prioritize questions that were answered incorrectly; fallback to all questions
    final incorrectQuestions = questions.where((q) => !q.isCorrect).toList();
    final questionsToUse = incorrectQuestions.isNotEmpty ? incorrectQuestions : questions;

    if (questionsToUse.isEmpty && result.weaknesses.isEmpty) {
      context.showSnackBar(
        message: 'No questions available to generate flashcards.',
      );
      return;
    }

    // Resolve course affiliation if not explicitly supplied
    var resolvedCourseId = courseId?.trim();
    var resolvedCourseCode = courseCode?.trim();

    if ((resolvedCourseId == null || resolvedCourseId.isEmpty) &&
        (resolvedCourseCode == null || resolvedCourseCode.isEmpty)) {
      if (locator.isRegistered<DecksBloc>()) {
        final allDecks = locator<DecksBloc>().state.allDecks;
        for (final d in allDecks) {
          if (d.courseCode != null &&
              d.courseCode!.isNotEmpty &&
              result.quizTitle.toLowerCase().contains(d.courseCode!.toLowerCase())) {
            resolvedCourseId = d.courseId;
            resolvedCourseCode = d.courseCode;
            break;
          }
        }
      }
    }

    final convertUseCase = locator.isRegistered<ConvertFailedQuizToDeckUseCase>()
        ? locator<ConvertFailedQuizToDeckUseCase>()
        : ConvertFailedQuizToDeckUseCase(locator<DecksRemoteDataSource>());

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
            message: failure.message ?? 'Failed to convert quiz to deck',
            type: SnackBarType.error,
          );
        }
      },
      (deck) {
        // Refresh DecksBloc & DashboardBloc
        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }

        if (context.mounted) {
          context.showSnackBar(
            message: 'Generated ${deck.totalCards} practice flashcards!',
            type: SnackBarType.success,
          );
          unawaited(
            context.router.replace(
              StudySessionRoute(deckId: deck.id),
            ),
          );
        }
      },
    );
  }
}
