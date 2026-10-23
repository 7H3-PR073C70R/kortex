import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/presentation/widgets/cbt_readiness_impact_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/session_summary/session_summary_actions_section.dart';
import 'package:kortex/src/features/decks/presentation/widgets/session_summary/session_summary_desktop_panel.dart';
import 'package:kortex/src/features/decks/presentation/widgets/session_summary/session_summary_header_section.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class SessionSummaryPage extends StatefulWidget {
  SessionSummaryPage({
    required this.deckId,
    required this.cardsReviewed,
    required this.durationSeconds,
    required this.retentionScore,
    this.nextReviewInDays = 0,
    LocalStorageService? localStorageService,
    UserActivityService? userActivityService,
    super.key,
  })  : localStorageService = localStorageService ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null),
        userActivityService = userActivityService ??
            (locator.isRegistered<UserActivityService>()
                ? locator<UserActivityService>()
                : null);

  final String deckId;
  final int cardsReviewed;
  final int durationSeconds;
  final double retentionScore;

  /// Days until the next scheduled review batch across the session's cards;
  /// 0 when unknown — the forward-looking line is then omitted.
  final int nextReviewInDays;

  final LocalStorageService? localStorageService;
  final UserActivityService? userActivityService;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3),
  );
  bool _celebrationStarted = false;

  /// Celebrate every completed deck review session.
  bool get _shouldCelebrate => widget.cardsReviewed > 0;

  String get _effectiveDeckId {
    final id = widget.deckId;
    if (id.startsWith('cram:') || id.startsWith('sprint:')) {
      final parts = id.split(':');
      return parts.length > 2 ? parts[2] : parts.last;
    }
    return id;
  }

  void _handleSafeExit(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      context.router.replaceAll([
        MainRoute(children: [DashboardRoute()]),
      ]),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_celebrationStarted) return;
    _celebrationStarted = true;
    final celebrate = _shouldCelebrate && !context.reduceMotion;
    if (celebrate) {
      _confettiController.play();
      unawaited(HapticFeedback.heavyImpact());
    } else {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = context.reduceMotion;

    final deckId = widget.deckId;
    final cardsReviewed = widget.cardsReviewed;
    final durationSeconds = widget.durationSeconds;
    final retentionScore = widget.retentionScore;

    final scorePercent = (retentionScore * 100).toInt();
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    final durationFormatted = '$minutes:$seconds';

    final celebrate = _shouldCelebrate;
    final isMastery = retentionScore >= 0.85;
    final summaryTitle = isMastery
        ? l10n.sessionSummaryDeckConquered
        : l10n.sessionSummaryTitle;

    final authState = context.watch<AuthBloc?>()?.state;
    final targetTrack = authState?.userProfile?.targetTrack;
    final savedTrack = widget.localStorageService?.getPreference(
      key: PrefKeys.userTargetTrack,
    );
    final examTitle = (targetTrack != null && targetTrack.trim().isNotEmpty)
        ? targetTrack.trim()
        : ((savedTrack != null && savedTrack.trim().isNotEmpty)
            ? savedTrack.trim()
            : 'JAMB');

    final dashboardFeed = context.watch<DashboardBloc?>()?.state.displayFeed;
    final plannerState = context.watch<CramPlannerCubit?>()?.state;

    var syllabusCoverage = 0.0;
    if (dashboardFeed != null && dashboardFeed.curatedCourses.isNotEmpty) {
      final total = dashboardFeed.curatedCourses.fold<double>(
        0,
        (sum, c) => sum + c.syllabusCoverage.clamp(0.0, 1.0),
      );
      syllabusCoverage = (total / dashboardFeed.curatedCourses.length).clamp(0.0, 1.0);
    }

    var mockScore = 0.0;
    final activityService = widget.userActivityService;
    if (activityService != null) {
      final quizMetrics = activityService.getQuizPerformanceMetrics();
      if (quizMetrics.overallMockAccuracy > 0) {
        mockScore = quizMetrics.overallMockAccuracy;
      }
    }

    final effectiveDaysRemaining = plannerState?.selectedExam?.daysRemaining ??
        (plannerState?.upcomingUncompletedExams.isNotEmpty == true
            ? plannerState!.upcomingUncompletedExams
                .map((e) => e.daysRemaining)
                .reduce(math.min)
            : (widget.nextReviewInDays > 0 ? widget.nextReviewInDays : null));

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final cbtCardWidget = CbtReadinessImpactCard(
      cardsReviewed: cardsReviewed,
      retentionScore: retentionScore,
      examTitle: examTitle,
      syllabusCoverage: syllabusCoverage,
      mockScore: mockScore,
      daysRemaining: effectiveDaysRemaining,
      registeredCourses: dashboardFeed?.curatedCourses,
    );

    final summaryHeader = SessionSummaryHeaderSection(
      cardsReviewed: cardsReviewed,
      scorePercent: scorePercent,
      durationFormatted: durationFormatted,
      celebrate: celebrate,
      isMastery: isMastery,
      summaryTitle: summaryTitle,
      reduceMotion: reduceMotion,
    );

    final visualizerAndActions = SessionSummaryActionsSection(
      deckId: deckId,
      effectiveDeckId: _effectiveDeckId,
      cardsReviewed: cardsReviewed,
      retentionScore: retentionScore,
      nextReviewInDays: widget.nextReviewInDays,
    );

    if (isDesktop) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _handleSafeExit(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SessionSummaryDesktopPanel(
              celebrate: celebrate,
              reduceMotion: reduceMotion,
              confettiController: _confettiController,
              onClose: () => _handleSafeExit(context),
              child: Column(
                children: [
                  summaryHeader,
                  const SizedBox(height: 16),
                  cbtCardWidget,
                  const SizedBox(height: 16),
                  visualizerAndActions,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _handleSafeExit(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (celebrate && !reduceMotion)
                Positioned(
                  top: 0,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: math.pi / 2,
                    maxBlastForce: 25,
                    minBlastForce: 10,
                    emissionFrequency: 0.05,
                    numberOfParticles: 35,
                    gravity: 0.15,
                    colors: [
                      colors.primary,
                      colors.success,
                      colors.warning,
                      colors.secondary,
                      colors.deepBronze,
                      colors.quartzCyan,
                    ],
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    // Top App Navigation Bar with Safe Exit
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Close summary',
                            child: ShrinkableButton(
                              onTap: () => _handleSafeExit(context),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colors.surfaceSecondary.withAlpha(160)
                                      : colors.surfacePrimary.withAlpha(220),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? colors.surfaceBorderHighlight.withAlpha(80)
                                        : colors.surfaceBorder.withAlpha(140),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withAlpha(isDark ? 30 : 10),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Session Summary',
                            style: typography.subhead.bold.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 38),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 580,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                summaryHeader,
                                const SizedBox(height: 16),
                                cbtCardWidget,
                                const SizedBox(height: 16),
                                visualizerAndActions,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
