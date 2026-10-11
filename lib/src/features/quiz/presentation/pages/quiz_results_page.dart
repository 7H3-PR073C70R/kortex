import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/services/assessment_orchestrator_service.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_results_action_handlers.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_results_actions_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_results_breakdown_section.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_results_score_hero.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

@RoutePage()
class QuizResultsPage extends StatefulWidget {
  const QuizResultsPage({
    required this.result,
    this.questions = const [],
    this.courseId,
    this.courseCode,
    this.assessmentMode = AssessmentMode.discoveryMode,
    this.currentTier = 1,
    this.bankedTier = 0,
    this.speedBonusXp = 0,
    this.isWalkedAway = false,
    this.showCelebrationDialog = true,
    this.subscriptionGuard,
    this.assessmentOrchestratorService,
    this.linkSharingService,
    this.convertFailedQuizToDeckUseCase,
    this.decksRepository,
    this.decksBloc,
    this.dashboardBloc,
    this.cramPlannerCubit,
    this.communityHubBloc,
    super.key,
  });

  final QuizResultEntity result;
  final List<QuizQuestionEntity> questions;
  final String? courseId;
  final String? courseCode;
  final AssessmentMode assessmentMode;
  final int currentTier;
  final int bankedTier;
  final int speedBonusXp;
  final bool isWalkedAway;
  final bool showCelebrationDialog;
  final SubscriptionGuard? subscriptionGuard;
  final AssessmentOrchestratorService? assessmentOrchestratorService;
  final LinkSharingService? linkSharingService;
  final ConvertFailedQuizToDeckUseCase? convertFailedQuizToDeckUseCase;
  final DecksRepository? decksRepository;
  final DecksBloc? decksBloc;
  final DashboardBloc? dashboardBloc;
  final CramPlannerCubit? cramPlannerCubit;
  final CommunityHubBloc? communityHubBloc;

  @override
  State<QuizResultsPage> createState() => _QuizResultsPageState();
}

class _QuizResultsPageState extends State<QuizResultsPage> {
  SubscriptionGuard? get _guard =>
      widget.subscriptionGuard ??
      (locator.isRegistered<SubscriptionGuard>()
          ? locator<SubscriptionGuard>()
          : null);

  AssessmentOrchestratorService? get _orchestrator =>
      widget.assessmentOrchestratorService ??
      (locator.isRegistered<AssessmentOrchestratorService>()
          ? locator<AssessmentOrchestratorService>()
          : null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final activeTrack =
          context.read<AuthBloc?>()?.state.userProfile?.targetTrack;

      QuizResultsActionHandlers.processPostCompletionTelemetry(
        result: widget.result,
        questions: widget.questions,
        courseCode: widget.courseCode,
        activeTrack: activeTrack,
        orchestrator: _orchestrator,
        dashboardBloc: widget.dashboardBloc,
        plannerCubit: widget.cramPlannerCubit,
      );

      if (widget.showCelebrationDialog) {
        QuizResultsActionHandlers.showCelebrationDialog(
          context: context,
          result: widget.result,
          questions: widget.questions,
          assessmentMode: widget.assessmentMode,
          currentTier: widget.currentTier,
          speedBonusXp: widget.speedBonusXp,
          onTryAgain: () => _handleTryAgain(context),
          onReviewMistakes: (mistakes) =>
              _openMistakeReview(context, mistakes),
        );
      }
    });
  }

  void _openMistakeReview(
    BuildContext context,
    List<QuizQuestionEntity> questionsToReview,
  ) {
    QuizResultsActionHandlers.openMistakeReview(
      context: context,
      result: widget.result,
      questionsToReview: questionsToReview,
      courseId: widget.courseId,
      courseCode: widget.courseCode,
    );
  }

  void _handleTryAgain(BuildContext context) {
    QuizResultsActionHandlers.handleTryAgain(
      context: context,
      result: widget.result,
      questions: widget.questions,
      courseId: widget.courseId,
      courseCode: widget.courseCode,
      assessmentMode: widget.assessmentMode,
    );
  }

  void _handleShareResult(BuildContext context) {
    unawaited(
      QuizResultsActionHandlers.handleShareResult(
        context: context,
        result: widget.result,
        linkSharingService: widget.linkSharingService,
      ),
    );
  }

  void _handleAskClassForHelp(BuildContext context) {
    QuizResultsActionHandlers.handleAskClassForHelp(
      context: context,
      result: widget.result,
      questions: widget.questions,
      courseCode: widget.courseCode,
      communityHubBloc: widget.communityHubBloc,
    );
  }

  void _handlePracticeWeakFlashcards(BuildContext context) {
    unawaited(
      QuizResultsActionHandlers.handlePracticeWeakFlashcards(
        context: context,
        result: widget.result,
        questions: widget.questions,
        courseId: widget.courseId,
        courseCode: widget.courseCode,
        subscriptionGuard: _guard,
        convertFailedQuizToDeckUseCase: widget.convertFailedQuizToDeckUseCase,
        decksRepository: widget.decksRepository,
        decksBloc: widget.decksBloc,
        dashboardBloc: widget.dashboardBloc,
        cramPlannerCubit: widget.cramPlannerCubit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    final isMillionaire =
        widget.assessmentMode == AssessmentMode.millionaireMode;
    final score = widget.result.scorePercent;
    final isPassed = isMillionaire || score >= kQuizPassScore;
    final bigWin = QuizResultsActionHandlers.isBigWin(
      score: score,
      mode: widget.assessmentMode,
      currentTier: widget.currentTier,
      isWalkedAway: widget.isWalkedAway,
    );
    final result = widget.result;
    final mistakes = QuizResultsActionHandlers.mistakeCount(
      result: result,
      questions: widget.questions,
    );
    final xpEarned = QuizResultsActionHandlers.xpEarned(
      result: result,
      mode: widget.assessmentMode,
      currentTier: widget.currentTier,
      speedBonusXp: widget.speedBonusXp,
    );
    final missedList =
        QuizResultsActionHandlers.missedQuestions(widget.questions);

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.transparent,
        titleText: result.quizTitle,
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Study Hub',
            onTap: () => context.router.popUntilRoot(),
          ),
          AppBreadcrumbItem(
            label: result.quizTitle.isNotEmpty ? result.quizTitle : 'Results',
          ),
        ],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => context.router.popUntilRoot(),
              child: Text(
                'Dashboard',
                style: typography.subhead.bold.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (isPassed && !bigWin)
                QuizInlineBanner(
                  icon: Icons.emoji_events_rounded,
                  tone: QuizBannerTone.success,
                  title: isMillionaire
                      ? 'Tier ${widget.currentTier} banked'
                      : 'You passed this one',
                  message:
                      'Nice work. Everything that needs another pass is listed below.',
                  reduceMotion: reduceMotion,
                ),

              // 1. Hero
              QuizStaggeredFade(
                reduceMotion: reduceMotion,
                child: isMillionaire
                    ? QuizMillionaireHero(
                        currentTier: widget.currentTier,
                        bankedTier: widget.bankedTier,
                        speedBonusXp: widget.speedBonusXp,
                        isWalkedAway: widget.isWalkedAway,
                      )
                    : QuizScoreHero(
                        result: result,
                        courseCode: widget.courseCode,
                      ),
              ),

              const SizedBox(height: 18),

              // 2. The three numbers that matter
              Row(
                children: [
                  Expanded(
                    child: QuizStatChip(
                      label: 'XP earned',
                      value: '+$xpEarned',
                      color: colors.primary,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Time taken',
                      value: QuizResultsActionHandlers.formatDuration(
                        result.durationSeconds,
                      ),
                      color: colors.syllabotAccent,
                      reduceMotion: reduceMotion,
                      staggerIndex: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Mistakes',
                      value: '$mistakes',
                      color: mistakes == 0 ? colors.success : colors.warning,
                      reduceMotion: reduceMotion,
                      staggerIndex: 2,
                    ),
                  ),
                ],
              ),

              // 3. Breakdown Section
              QuizResultsBreakdownSection(
                result: result,
                mistakes: mistakes,
                hasQuestions: widget.questions.isNotEmpty,
                orchestratorService: _orchestrator,
                subscriptionGuard: _guard,
                onTryAgain: () => _handleTryAgain(context),
                onPracticeFlashcards: () =>
                    _handlePracticeWeakFlashcards(context),
                onAskClass: () => _handleAskClassForHelp(context),
                onShare: () => _handleShareResult(context),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: QuizResultsActionsBar(
        canRestart: widget.questions.isNotEmpty,
        hasMistakesToReview: missedList.isNotEmpty,
        mistakesCount: missedList.length,
        questionsCount: widget.questions.length,
        onRetake: () => _handleTryAgain(context),
        onReviewAction: () {
          if (missedList.isNotEmpty) {
            _openMistakeReview(context, missedList);
          } else if (widget.questions.isNotEmpty) {
            _openMistakeReview(context, widget.questions);
          } else {
            context.router.popUntilRoot();
          }
        },
      ),
    );
  }
}
