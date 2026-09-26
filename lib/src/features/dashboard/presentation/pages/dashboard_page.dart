import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:auto_route/auto_route.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curated_course_carousel.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/fsrs_review_deck_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/quick_action_speed_dial.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/retention_heat_map_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/track_selection_modal_sheet.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class DashboardPage extends HookWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cramPlannerCubit = locator<CramPlannerCubit>();
    final dashboardBloc = locator<DashboardBloc>();

    useEffect(() {
      unawaited(cramPlannerCubit.loadExams());
      dashboardBloc.add(const DashboardStarted());
      return null;
    }, const []);

    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>.value(
          value: dashboardBloc,
        ),
        BlocProvider<CramPlannerCubit>.value(
          value: cramPlannerCubit,
        ),
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends HookWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final authState = context.watch<AuthBloc?>()?.state;
    final userName =
        authState?.userProfile?.displayName ?? authState?.user?.displayName;
    final userPhotoUrl =
        authState?.userProfile?.photoUrl ?? authState?.user?.photoUrl;
    final targetTrack = authState?.userProfile?.targetTrack;

    final confettiController = useMemoized(
      () => ConfettiController(duration: const Duration(seconds: 4)),
    );
    useEffect(() => confettiController.dispose, [confettiController]);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final storage = locator<LocalStorageService>();
        final userId = authState?.userProfile?.id ?? authState?.user?.id ?? '';
        final userSeenKey = '${PrefKeys.hasSeenWelcomeWalkthrough}_$userId';
        final isNewlyRegistered =
            storage.getPreference(key: PrefKeys.isNewlyRegistered) == 'true';
        final hasSeenWelcome =
            (userId.isNotEmpty &&
                storage.getPreference(key: userSeenKey) == 'true') ||
            storage.getPreference(key: PrefKeys.hasSeenWelcomeWalkthrough) ==
                'true';

        // Welcome dialog should ONLY show to newly registered users who just created their account,
        // and never to users who already own an account and are logging back in.
        final shouldShowWelcome = isNewlyRegistered && !hasSeenWelcome;

        if (shouldShowWelcome && context.mounted) {
          confettiController.play();
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => WelcomeWalkthroughDialog(
                onDismissed: () {
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.hasSeenWelcomeWalkthrough,
                      data: 'true',
                    ),
                  );
                  if (userId.isNotEmpty) {
                    unawaited(
                      storage.savePreference(
                        key: userSeenKey,
                        data: 'true',
                      ),
                    );
                  }
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.isNewlyRegistered,
                      data: 'false',
                    ),
                  );
                },
                onEnterWorkspace: () {
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.hasSeenWelcomeWalkthrough,
                      data: 'true',
                    ),
                  );
                  if (userId.isNotEmpty) {
                    unawaited(
                      storage.savePreference(
                        key: userSeenKey,
                        data: 'true',
                      ),
                    );
                  }
                  unawaited(
                    storage.savePreference(
                      key: PrefKeys.isNewlyRegistered,
                      data: 'false',
                    ),
                  );
                  if (context.mounted) {
                    unawaited(AppGuidedTourOverlay.start(context));
                  }
                },
              ),
            ),
          );
        } else if (!hasSeenWelcome) {
          unawaited(
            storage.savePreference(
              key: PrefKeys.hasSeenWelcomeWalkthrough,
              data: 'true',
            ),
          );
          if (userId.isNotEmpty) {
            unawaited(
              storage.savePreference(
                key: userSeenKey,
                data: 'true',
              ),
            );
          }
        }

        final profileTrack = authState?.userProfile?.targetTrack;
        final effectiveTrack = (profileTrack != null && profileTrack.trim().isNotEmpty)
            ? profileTrack.trim()
            : (targetTrack != null && targetTrack.trim().isNotEmpty
                ? targetTrack.trim()
                : '');
        final hasTrack = effectiveTrack.isNotEmpty;

        if (hasTrack && userId.isNotEmpty) {
          final promptKey = 'prompted_track_$userId';
          unawaited(storage.savePreference(key: promptKey, data: 'true'));
        }
      });
      return null;
    }, [authState?.status, authState?.userProfile?.targetTrack, targetTrack]);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const _DashboardShimmerLoading();
                }

                if (state.isError || state.feed == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SyllabotAvatar(size: 48, isError: true),
                          const SizedBox(height: 16),
                          Text(
                            l10n.dashboardUnableToLoad,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.errorMessage ?? l10n.dashboardConnectionError,
                            textAlign: TextAlign.center,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ShrinkableButton(
                            onTap: () {
                              context.read<DashboardBloc>().add(
                                const DashboardStarted(),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                l10n.dashboardRetry,
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final feed = state.feed!;

                return RefreshIndicator(
                  onRefresh: () async {
                    final completer = Completer<void>();
                    context.read<DashboardBloc>().add(
                      const DashboardRefreshed(),
                    );
                    Timer(
                      const Duration(milliseconds: 600),
                      completer.complete,
                    );
                    return completer.future;
                  },
                  color: colors.primary,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isExpanded = constraints.maxWidth >= 1024;
                      final isMedium =
                          constraints.maxWidth >= 600 && !isExpanded;

                      if (isExpanded) {
                        return _ExpandedDashboardLayout(
                          feed: feed,
                          userName: userName,
                          userPhotoUrl: userPhotoUrl,
                          targetTrack: targetTrack,
                        );
                      } else if (isMedium) {
                        return _MediumDashboardLayout(
                          feed: feed,
                          userName: userName,
                          userPhotoUrl: userPhotoUrl,
                          targetTrack: targetTrack,
                        );
                      } else {
                        return _CompactDashboardLayout(
                          feed: feed,
                          userName: userName,
                          userPhotoUrl: userPhotoUrl,
                          targetTrack: targetTrack,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          // Confetti celebration overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 45,
              emissionFrequency: 0.05,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.25,
              colors: [
                colors.primary,
                colors.syllabotAccent,
                colors.warning,
                colors.success,
                colors.surfaceBorderHighlight,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardShimmerLoading extends StatelessWidget {
  const _DashboardShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // 1. Header Profile Skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ShimmerPlaceholder(
                  height: 46,
                  width: 46,
                  borderRadius: 23,
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerPlaceholder(
                      height: 18,
                      width: 120,
                      borderRadius: 6,
                    ),
                    SizedBox(height: 6),
                    ShimmerPlaceholder(
                      height: 12,
                      width: 80,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                ShimmerPlaceholder(
                  height: 32,
                  width: 56,
                  borderRadius: 16,
                ),
                SizedBox(width: 8),
                ShimmerPlaceholder(
                  height: 38,
                  width: 38,
                  borderRadius: 19,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Exam Countdown Banner Skeleton
        const ShimmerPlaceholder(height: 72, borderRadius: 18),
        const SizedBox(height: 20),

        // 3. Next Best Action Skeleton
        const ShimmerPlaceholder(height: 130, borderRadius: 22),
        const SizedBox(height: 20),

        // 4. Hero Deck Skeleton
        const ShimmerPlaceholder(height: 180, borderRadius: 22),
        const SizedBox(height: 20),

        // 5. Curated Courses Skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerPlaceholder(height: 18, width: 140, borderRadius: 6),
            ShimmerPlaceholder(height: 14, width: 60, borderRadius: 6),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (_, index) => const ShimmerPlaceholder(
              width: 220,
              height: 155,
              borderRadius: 18,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 6. Quick Actions Speed Dial Skeleton
        const ShimmerPlaceholder(height: 48, borderRadius: 22),
        const SizedBox(height: 20),

        // 7. Retention Heatmap Skeleton
        const ShimmerPlaceholder(height: 160, borderRadius: 22),
      ],
    );
  }
}

/// Compact Viewport (< 600dp) Single-Column Scroll — Stitch-aligned layout
class _CompactDashboardLayout extends StatelessWidget {
  const _CompactDashboardLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
    this.targetTrack,
  });

  final DashboardFeedEntity feed;
  final String? userName;
  final String? userPhotoUrl;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final heavyDebtDeck = feed.dueStudyDecks
        .where((d) => d.dueCards >= 30)
        .firstOrNull;

    return ListView(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children:
          <Widget>[
                // 1. User Profile Header (Identity & Streak Anchor)
                HeaderProfileBar(
                  key: AppTourKeys.headerProfileKey,
                  analytics: feed.analyticsSummary,
                  isProfileUncalibrated: feed.isProfileUncalibrated,
                  userName: userName,
                  userPhotoUrl: userPhotoUrl,
                ),
                const SizedBox(height: 16),

                // Prompt track selection if not selected yet
                if (targetTrack == null || targetTrack!.trim().isEmpty) ...[
                  const _SelectTrackPromptBanner(),
                  const SizedBox(height: 16),
                ],

                // 2. Exam Countdown Banner + Backlog Debt Triage
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  child: Column(
                    children: [
                      if (feed.curatedCourses.isNotEmpty) ...[
                        ExamCountdownBanner(key: AppTourKeys.countdownKey),
                        const SizedBox(height: 16),
                      ],
                      if (heavyDebtDeck != null) ...[
                        _StudyDebtTriageBanner(deck: heavyDebtDeck),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // 3. Daily Recall Status Banner ("All caught up!" / due-cards state)
                _DailyRecallStatusBanner(
                  key: AppTourKeys.reviewQueueKey,
                  feed: feed,
                ),

                const SizedBox(height: 16),

                // 4. Quick Actions Grid (Upload Notes | Q-Bank | 1v1 Duel | New Deck)
                _QuickActionsGrid(key: AppTourKeys.quickActionsKey),
                const SizedBox(height: 16),

                // 5. Curated Course Repositories
                if (feed.curatedCourses.isNotEmpty) ...[
                  CuratedCourseCarousel(courses: feed.curatedCourses),
                  const SizedBox(height: 16),
                ] else ...[
                  _EmptyCoursesCard(l10n: l10n),
                  const SizedBox(height: 16),
                ],

                // 6. Pod Pulse — Study Circle Co-presence
                _StudyCirclePodPulseCard(targetTrack: targetTrack),
                const SizedBox(height: 16),

                // 7. Retention Heat Map & Mastery Stats
                RetentionHeatMapWidget(analytics: feed.analyticsSummary),
              ]
              .animate(interval: 80.ms)
              .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuint),
    );
  }
}

/// Glass "All caught up! SYNCED" banner — mirrors the Stitch DailyStatusRecallBanner.
/// Shows due-card count + deck title when reviews are pending.
class _DailyRecallStatusBanner extends StatelessWidget {
  const _DailyRecallStatusBanner({required this.feed, super.key});

  final DashboardFeedEntity feed;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    final hasDueCards = feed.dueStudyDecks.any((d) => d.dueCards > 0);
    final topDueDeck = hasDueCards
        ? feed.dueStudyDecks.firstWhere((d) => d.dueCards > 0)
        : null;

    // Design uses emerald for the synced state; amber mirrors it for due cards.
    final accent = hasDueCards ? neural.amber : neural.emerald;
    final accent400 = hasDueCards ? neural.amber400 : neural.emerald400;
    final accent300 = hasDueCards ? neural.amber300 : neural.emerald300;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: neural.glassPanel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withAlpha(77)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent400.withAlpha(77)),
                    ),
                    child: Icon(
                      hasDueCards
                          ? Icons.hourglass_top_rounded
                          : Icons.check_circle_rounded,
                      color: accent400,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                hasDueCards
                                    ? l10n.dashboardDueCount(
                                        topDueDeck!.dueCards,
                                      )
                                    : l10n.allCaughtUpTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.callout.bold.copyWith(
                                  color: neural.slate100,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(51),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: accent.withAlpha(77),
                                ),
                              ),
                              child: Text(
                                hasDueCards
                                    ? l10n.dashboardReviewDeck.toUpperCase()
                                    : 'SYNCED',
                                style: typography.caption.bold.copyWith(
                                  color: accent300,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasDueCards
                              ? topDueDeck!.title
                              : l10n.allCaughtUpSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.regular.copyWith(
                            color: neural.slate300.withAlpha(204),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Ambient accent lighting glow (top-right, clipped by panel)
            Positioned(
              right: -32,
              top: -32,
              child: IgnorePointer(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [accent.withAlpha(38), accent.withAlpha(0)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4-column quick actions glass grid — mirrors the Stitch QuickActionsRow.
/// Upload Notes | Q-Bank | 1v1 Duel | New Deck
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final l10n = context.l10n;

    String? getTrackCode() {
      try {
        final track = context.read<AuthBloc>().state.userProfile?.targetTrack;
        if (track != null && track.isNotEmpty) return track;
      } on Object catch (_) {}
      return null;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: neural.glassPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neural.hairline),
          ),
          child: SizedBox(
            height: 124,
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Upload Notes
                Expanded(
                  child: _QuickActionCell(
                    icon: Icons.upload_file_rounded,
                    label: l10n.dashboardUploadNotes,
                    accent: neural.emerald400,
                    onTap: () {
                      AppFeedback.light();
                      _showUploadSheet(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Q-Bank
                Expanded(
                  child: _QuickActionCell(
                    icon: Icons.quiz_rounded,
                    label: l10n.dashboardQBankAction,
                    accent: neural.amber400,
                    onTap: () {
                      AppFeedback.light();
                      final trackCode = getTrackCode();
                      unawaited(
                        context.router.push(
                          PastQuestionsBoardRoute(initialExamCode: trackCode),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 1v1 Duel
                Expanded(
                  child: _QuickActionCell(
                    icon: Icons.flash_on_rounded,
                    label: '1v1 Duel',
                    accent: neural.cyan400,
                    onTap: () {
                      AppFeedback.light();
                      unawaited(QuizDuelMatchmakingSheet.show(context));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // New Deck
                Expanded(
                  child: _QuickActionCell(
                    icon: Icons.create_new_folder_outlined,
                    label: l10n.dashboardNewDeck,
                    accent: neural.violet,
                    onTap: () {
                      AppFeedback.light();
                      try {
                        AutoTabsRouter.of(context).setActiveIndex(1);
                      } on Object catch (_) {
                        unawaited(
                          context.navigateTo(
                            const MainRoute(children: [DecksRoute()]),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadSheet(BuildContext context) {
    // Delegates to QuickActionSpeedDial's upload sheet logic via same bottom sheet
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(240)
                      : colors.surfacePrimary.withAlpha(245),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withAlpha(100),
                        borderRadius: BorderRadius.circular(AppRadius.micro),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.dashboardIngestTitle,
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.dashboardIngestSubtitle,
                      textAlign: TextAlign.center,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ShrinkableButton(
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(
                          context.router.push(DocumentIngestionRoute()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: AppRadius.radiusCard,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.dashboardUploadNotes,
                          style: typography.callout.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ShrinkableButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.surfacePrimary.withAlpha(
                            isDark ? 180 : 230,
                          ),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: colors.surfaceBorder.withAlpha(
                              isDark ? 50 : 30,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.cancelAction,
                          style: typography.callout.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionCell extends StatelessWidget {
  const _QuickActionCell({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: neural.obsidian850.withAlpha(204),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: neural.hairlineSoft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.medium.copyWith(
                color: neural.slate200,
                fontSize: 13.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStudyDecksCard extends StatelessWidget {
  const _EmptyStudyDecksCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ClipRRect(
      borderRadius: AppRadius.radiusPanel,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(140)
              : colors.surfacePrimary.withAlpha(210),
          borderRadius: AppRadius.radiusPanel,
          // Removed border for premium UI
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.success.withAlpha(isDark ? 40 : 20),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: colors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.allCaughtUpTitle,
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.allCaughtUpSubtitle,
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCoursesCard extends StatelessWidget {
  const _EmptyCoursesCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: () async {
        final result = await context.router.push(CurateCoursesRoute());
        if (result == true && context.mounted) {
          context.read<DashboardBloc>().add(const DashboardRefreshed());
        }
      },
      child: ClipRRect(
        borderRadius: AppRadius.radiusPanel,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary.withAlpha(210),
            borderRadius: AppRadius.radiusPanel,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.curateCoursesTitle,
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.curateCoursesSubtitle,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Medium Viewport (600dp - 1024dp - Tablet) Two-Column Bento Layout
class _MediumDashboardLayout extends StatelessWidget {
  const _MediumDashboardLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
    this.targetTrack,
  });

  final DashboardFeedEntity feed;
  final String? userName;
  final String? userPhotoUrl;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final heavyDebtDeck = feed.dueStudyDecks
        .where((d) => d.dueCards >= 30)
        .firstOrNull;

    return ListView(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      children:
          <Widget>[
                HeaderProfileBar(
                  analytics: feed.analyticsSummary,
                  isProfileUncalibrated: feed.isProfileUncalibrated,
                  userName: userName,
                  userPhotoUrl: userPhotoUrl,
                ),
                const SizedBox(height: 20),

                // Prompt track selection if not selected yet
                if (targetTrack == null || targetTrack!.trim().isEmpty) ...[
                  const _SelectTrackPromptBanner(),
                  const SizedBox(height: 20),
                ],
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  child: Column(
                    children: [
                      if (feed.curatedCourses.isNotEmpty) ...[
                        const ExamCountdownBanner(),
                        const SizedBox(height: 20),
                      ],
                      if (heavyDebtDeck != null) ...[
                        _StudyDebtTriageBanner(deck: heavyDebtDeck),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
                if (feed.dueStudyDecks.any((d) => d.totalCards > 0)) ...[
                  _NextBestActionCard(
                    topDeck: feed.dueStudyDecks.firstWhere(
                      (d) => d.totalCards > 0,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Core Learning & Curriculum - flex 6)
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          if (feed.dueStudyDecks.isNotEmpty)
                            FsrsReviewDeckCard(
                              deck: feed.dueStudyDecks.first,
                              isHero: true,
                            )
                          else
                            _EmptyStudyDecksCard(l10n: context.l10n),
                          const SizedBox(height: 20),
                          if (feed.dueStudyDecks.length > 1) ...[
                            if (feed.dueStudyDecks.length - 1 == 1)
                              FsrsReviewDeckCard(deck: feed.dueStudyDecks[1])
                            else
                              SizedBox(
                                height: 205,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: feed.dueStudyDecks.length - 1,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final deck = feed.dueStudyDecks[index + 1];
                                    return SizedBox(
                                      width: 300,
                                      child: FsrsReviewDeckCard(deck: deck),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                          if (feed.curatedCourses.isNotEmpty)
                            CuratedCourseCarousel(courses: feed.curatedCourses)
                          else
                            _EmptyCoursesCard(l10n: context.l10n),
                          const SizedBox(height: 20),
                          const QuickActionSpeedDial(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right Column (Social Cohort & Analytics - flex 4)
                    Expanded(
                      flex: 4,
                      child: Column(
                        children:
                            [
                                  _StudyCirclePodPulseCard(
                                    targetTrack: targetTrack,
                                  ),
                                  const SizedBox(height: 20),
                                  RetentionHeatMapWidget(
                                    analytics: feed.analyticsSummary,
                                  ),
                                ]
                                .animate(interval: 80.ms)
                                .fadeIn(
                                  duration: 400.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.05,
                                  end: 0,
                                  curve: Curves.easeOutQuint,
                                ),
                      ),
                    ),
                  ],
                ),
              ]
              .animate(interval: 80.ms)
              .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuint),
    );
  }
}

/// Expanded Viewport (>= 1024dp - Desktop/Web) Asymmetric Bento Grid Workstation
class _ExpandedDashboardLayout extends StatelessWidget {
  const _ExpandedDashboardLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
    this.targetTrack,
  });

  final DashboardFeedEntity feed;
  final String? userName;
  final String? userPhotoUrl;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final heavyDebtDeck = feed.dueStudyDecks
        .where((d) => d.dueCards >= 30)
        .firstOrNull;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: ListView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 100),
          children:
              <Widget>[
                    // 1. Identity & Retention Anchor Header
                    HeaderProfileBar(
                      analytics: feed.analyticsSummary,
                      isProfileUncalibrated: feed.isProfileUncalibrated,
                      userName: userName,
                      userPhotoUrl: userPhotoUrl,
                    ),
                    const SizedBox(height: 24),

                    // Prompt track selection if not selected yet
                    if (targetTrack == null || targetTrack!.trim().isEmpty) ...[
                      const _SelectTrackPromptBanner(),
                      const SizedBox(height: 24),
                    ],

                    // 2. Urgent Callouts (with AnimatedSize for layout stability)
                    AnimatedSize(
                      alignment: Alignment.topCenter,
                      duration: AppMotion.standard,
                      curve: AppMotion.easeOutCubic,
                      child: Column(
                        children: [
                          if (feed.curatedCourses.isNotEmpty) ...[
                            const ExamCountdownBanner(),
                            const SizedBox(height: 20),
                          ],
                          if (heavyDebtDeck != null) ...[
                            _StudyDebtTriageBanner(deck: heavyDebtDeck),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),

                    // 3. Asymmetric Bento Grid Workstation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary Focus Workstation Column (flex: 7)
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children:
                                [
                                      // 1-Tap Sprint Tile
                                      if (feed.dueStudyDecks.any(
                                        (d) => d.totalCards > 0,
                                      )) ...[
                                        _NextBestActionCard(
                                          topDeck: feed.dueStudyDecks
                                              .firstWhere(
                                                (d) => d.totalCards > 0,
                                              ),
                                        ),
                                        const SizedBox(height: 20),
                                      ],

                                      // Hero FSRS Active Recall Card
                                      if (feed.dueStudyDecks.isNotEmpty) ...[
                                        FsrsReviewDeckCard(
                                          deck: feed.dueStudyDecks.first,
                                          isHero: true,
                                        ),
                                        if (feed.dueStudyDecks.length > 1) ...[
                                          const SizedBox(height: 20),
                                          _DesktopSpacedRepetitionGrid(
                                            decks: feed.dueStudyDecks
                                                .skip(1)
                                                .toList(),
                                          ),
                                        ],
                                      ] else ...[
                                        _EmptyStudyDecksCard(
                                          l10n: context.l10n,
                                        ),
                                      ],
                                      const SizedBox(height: 24),

                                      // Curated Courses Repository
                                      if (feed.curatedCourses.isNotEmpty)
                                        CuratedCourseCarousel(
                                          courses: feed.curatedCourses,
                                        )
                                      else
                                        _EmptyCoursesCard(l10n: context.l10n),
                                    ]
                                    .animate(interval: 80.ms)
                                    .fadeIn(
                                      duration: 400.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .slideY(
                                      begin: 0.05,
                                      end: 0,
                                      curve: Curves.easeOutQuint,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Workstation Telemetry & Toolbox Column (flex: 5)
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children:
                                [
                                      // Real-time Cohort Presence
                                      _StudyCirclePodPulseCard(
                                        targetTrack: targetTrack,
                                      ),
                                      const SizedBox(height: 20),

                                      // Retention Heatmap & Mastery Matrix
                                      RetentionHeatMapWidget(
                                        analytics: feed.analyticsSummary,
                                      ),
                                      const SizedBox(height: 20),

                                      // Speed Dial / Action Toolbox
                                      const QuickActionSpeedDial(),
                                    ]
                                    .animate(interval: 80.ms)
                                    .fadeIn(
                                      duration: 400.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .slideY(
                                      begin: 0.05,
                                      end: 0,
                                      curve: Curves.easeOutQuint,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ]
                  .animate(interval: 80.ms)
                  .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuint),
        ),
      ),
    );
  }
}

/// Responsive Grid for remaining queued decks on Desktop Workstation
class _DesktopSpacedRepetitionGrid extends StatelessWidget {
  const _DesktopSpacedRepetitionGrid({required this.decks});

  final List<StudyDeckEntity> decks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dashboardSpacedRepetitionQueue,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15.5,
                ),
              ),
              Text(
                l10n.dashboardDecksCount(decks.length),
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 185,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: decks.length,
          itemBuilder: (context, index) {
            return FsrsReviewDeckCard(deck: decks[index])
                .animate(delay: (index * 80).ms)
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuint);
          },
        ),
      ],
    );
  }
}

/// Behavioral decision-fatigue reducer: 1-Tap Next Best Action Card
class _NextBestActionCard extends StatelessWidget {
  const _NextBestActionCard({
    required this.topDeck,
  });

  final StudyDeckEntity topDeck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final badgeLabel = l10n.fifteenMinSprint;
    final actionTitle = l10n.dashboardReviewDeck;

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: () {
            AppFeedback.selection();
            unawaited(
              context.router.push(
                StudySessionRoute(deckId: 'sprint:10:${topDeck.id}'),
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withAlpha(
                    isDark ? (isHovered ? 75 : 55) : (isHovered ? 35 : 25),
                  ),
                  colors.syllabotAccent.withAlpha(
                    isDark ? (isHovered ? 55 : 40) : (isHovered ? 25 : 18),
                  ),
                ],
              ),
              borderRadius: AppRadius.radiusPanel,
              // Removed border
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(
                    isDark ? (isHovered ? 40 : 20) : (isHovered ? 15 : 8),
                  ),
                  blurRadius: isHovered ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.syllabotAccent],
                    ),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.nextBestActionTitle,
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Text(
                              badgeLabel,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$actionTitle: ${topDeck.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Text(
                    l10n.startAction,
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Real-time cohort accountability and peer co-presence indicator
class _StudyCirclePodPulseCard extends StatelessWidget {
  const _StudyCirclePodPulseCard({this.targetTrack});

  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    final trackLabel = (targetTrack != null && targetTrack!.trim().isNotEmpty)
        ? l10n.podSuffix(targetTrack!)
        : l10n.studyCirclePod;

    final activityService = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>()
        : null;
    final weeklyMinutes = activityService?.getWeeklyMinutesStudied() ?? 0;
    final userXp = activityService?.getXpPoints() ?? 0;

    var activeMembers = 1;
    var maxMembers = 6;
    try {
      if (locator.isRegistered<CommunityHubBloc>()) {
        final circles = locator<CommunityHubBloc>().state.studyCircles;
        if (circles.isNotEmpty) {
          activeMembers = circles.first.memberCount;
          maxMembers = circles.first.maxMembers;
        }
      }
    } on Object catch (_) {}

    final activeStr = '$activeMembers/$maxMembers';
    final minutesStr = weeklyMinutes > 0 ? '${weeklyMinutes}m' : '0m';
    final karmaStr = '+$userXp';

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            unawaited(context.navigateTo(const CommunityHubRoute()));
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: neural.glassPanel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHovered
                        ? neural.emerald.withAlpha(51)
                        : neural.hairline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: live dot + POD PULSE + pod link
                    Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: neural.hairlineSoft),
                        ),
                      ),
                      child: Row(
                        children: [
                          AppPulsingBeacon(
                            color: neural.emerald,
                            pulseSpread: 5,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.podPulseTitle,
                            style: typography.caption.bold.copyWith(
                              color: neural.emerald400,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            trackLabel,
                            style: typography.caption.medium.copyWith(
                              color: neural.slate300,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: neural.slate400,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PodMetricChip(
                            icon: Icons.group_rounded,
                            iconColor: neural.emerald400,
                            value: activeStr,
                            label: l10n.activeToday,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PodMetricChip(
                            icon: Icons.timer_outlined,
                            iconColor: neural.amber400,
                            value: minutesStr,
                            label: l10n.groupFocus,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PodMetricChip(
                            icon: Icons.bolt_rounded,
                            iconColor: neural.cyan400,
                            value: karmaStr,
                            valueColor: neural.cyan300,
                            label: l10n.podKarma,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PodMetricChip extends StatelessWidget {
  const _PodMetricChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: neural.obsidian850.withAlpha(153),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neural.hairlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: typography.caption.bold.copyWith(
                  color: valueColor ?? neural.slate300,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.caption.regular.copyWith(
              color: neural.slate400,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overcomes backlog avoidance / study debt paralysis through gentle FSRS triage
class _StudyDebtTriageBanner extends StatelessWidget {
  const _StudyDebtTriageBanner({required this.deck});

  final StudyDeckEntity deck;

  void _startSprint(BuildContext context, int count) {
    AppFeedback.medium();
    unawaited(
      context.router.push(
        StudySessionRoute(deckId: 'sprint:$count:${deck.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.warning.withAlpha(isDark ? 50 : 25),
            colors.surfaceSecondary.withAlpha(isDark ? 160 : 240),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusPanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.warning.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.healing_rounded,
                  color: colors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.backlogTriageTitle,
                          style: typography.caption.bold.copyWith(
                            color: colors.warning,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withAlpha(30),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            l10n.dashboardDueCount(deck.dueCards),
                            style: typography.caption.bold.copyWith(
                              color: colors.warning,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.backlogTriageSubtitle,
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.backlogTriageBody(deck.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Sprint Triage:',
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SprintModeChip(
                      label: '5 Cards',
                      onTap: () => _startSprint(context, 5),
                    ),
                    const SizedBox(width: 6),
                    _SprintModeChip(
                      label: '10 Cards',
                      isRecommended: true,
                      onTap: () => _startSprint(context, 10),
                    ),
                    const SizedBox(width: 6),
                    _SprintModeChip(
                      label: '15 Cards',
                      onTap: () => _startSprint(context, 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SprintModeChip extends StatelessWidget {
  const _SprintModeChip({
    required this.label,
    required this.onTap,
    this.isRecommended = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Expanded(
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isRecommended ? colors.warning : colors.warning.withAlpha(30),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: colors.warning.withAlpha(isRecommended ? 255 : 80),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: typography.caption.bold.copyWith(
              color: isRecommended ? colors.white : colors.warning,
              fontSize: 10.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectTrackPromptBanner extends StatelessWidget {
  const _SelectTrackPromptBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            unawaited(TrackSelectionModalSheet.show(context));
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        colors.primary.withAlpha(50),
                        colors.surfaceSecondary.withAlpha(240),
                      ]
                    : [
                        colors.primary.withAlpha(25),
                        colors.surfacePrimary,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isHovered
                    ? colors.primary
                    : colors.primary.withAlpha(isDark ? 120 : 80),
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                  blurRadius: isHovered ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 60 : 35),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 140 : 90),
                    ),
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Select Your Academic Track',
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Text(
                              'SETUP',
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                                fontSize: 9,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap here to choose WAEC, JAMB, B.Sc Degree, NECO, or postgraduate level.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Select',
                        style: typography.footnote.bold.copyWith(
                          color: colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
