import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
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
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';
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
        final isNewlyRegistered =
            storage.getPreference(key: PrefKeys.isNewlyRegistered) == 'true';
        final hasSeenWelcome =
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
        } else if (!isNewlyRegistered && !hasSeenWelcome) {
          unawaited(
            storage.savePreference(
              key: PrefKeys.hasSeenWelcomeWalkthrough,
              data: 'true',
            ),
          );
        }
      });
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: colors.transparent,
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

/// Compact Viewport (< 600dp) Single-Column Scroll
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
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final heavyDebtDeck = feed.dueStudyDecks
        .where((d) => d.dueCards >= 30)
        .firstOrNull;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // 1. Header Profile & Streak Bar (Identity & Retention Anchor)
        HeaderProfileBar(
          analytics: feed.analyticsSummary,
          isProfileUncalibrated: feed.isProfileUncalibrated,
          userName: userName,
          userPhotoUrl: userPhotoUrl,
        ),
        const SizedBox(height: 20),

        // 2 & 3. Exam Countdown & Backlog Debt Triage (AnimatedSize for stability)
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

        // 4. Next Best Action (Single-Tap Focus Sprint - Overcomes Decision Fatigue)
        if (feed.dueStudyDecks.any((d) => d.totalCards > 0)) ...[
          _NextBestActionCard(
            topDeck: feed.dueStudyDecks.firstWhere((d) => d.totalCards > 0),
          ),
          const SizedBox(height: 20),
        ],

        // 5. Active Recall FSRS-6 Review Engine (Hero Deck + Spaced Repetition Queue)
        if (feed.dueStudyDecks.isNotEmpty) ...[
          FsrsReviewDeckCard(
            deck: feed.dueStudyDecks.first,
            isHero: true,
          ),
          if (feed.dueStudyDecks.length > 1) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.dashboardSpacedRepetitionQueue,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16.5,
                    ),
                  ),
                  Text(
                    l10n.dashboardDecksCount(feed.dueStudyDecks.length),
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (feed.dueStudyDecks.length - 1 == 1)
              FsrsReviewDeckCard(deck: feed.dueStudyDecks[1])
            else
              SizedBox(
                height: 205,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: feed.dueStudyDecks.length - 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final deck = feed.dueStudyDecks[index + 1];
                    return SizedBox(
                      width: 300,
                      child: FsrsReviewDeckCard(deck: deck),
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 20),
        ] else ...[
          _EmptyStudyDecksCard(l10n: l10n),
          const SizedBox(height: 20),
        ],

        // 6. Curated Courses Carousel (Subject Progress & Syllabus)
        if (feed.curatedCourses.isNotEmpty) ...[
          CuratedCourseCarousel(courses: feed.curatedCourses),
          const SizedBox(height: 20),
        ] else ...[
          _EmptyCoursesCard(l10n: l10n),
          const SizedBox(height: 20),
        ],

        // 7. Quick Action Speed Dial Bar (Scan Document, Add Question, Create Deck, Live Pod)
        const QuickActionSpeedDial(),
        const SizedBox(height: 20),

        // 8. Study Circle Pod & Cohort Pulse (Social Proof & Live Co-Working)
        _StudyCirclePodPulseCard(targetTrack: targetTrack),
        const SizedBox(height: 20),

        // 9. Retention Heat Map & Mastery Stats (Long-Term Proof of Progress)
        RetentionHeatMapWidget(analytics: feed.analyticsSummary),
      ],
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
          border: Border.all(
            color: colors.surfaceBorder,
          ),
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
            border: Border.all(
              color: colors.surfaceBorder,
            ),
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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      children: [
        HeaderProfileBar(
          analytics: feed.analyticsSummary,
          isProfileUncalibrated: feed.isProfileUncalibrated,
          userName: userName,
          userPhotoUrl: userPhotoUrl,
        ),
        const SizedBox(height: 20),
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
            topDeck: feed.dueStudyDecks.firstWhere((d) => d.totalCards > 0),
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
                          physics: const BouncingScrollPhysics(),
                          itemCount: feed.dueStudyDecks.length - 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
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
                children: [
                  _StudyCirclePodPulseCard(targetTrack: targetTrack),
                  const SizedBox(height: 20),
                  RetentionHeatMapWidget(analytics: feed.analyticsSummary),
                ],
              ),
            ),
          ],
        ),
      ],
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
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 100),
          children: [
            // 1. Identity & Retention Anchor Header
            HeaderProfileBar(
              analytics: feed.analyticsSummary,
              isProfileUncalibrated: feed.isProfileUncalibrated,
              userName: userName,
              userPhotoUrl: userPhotoUrl,
            ),
            const SizedBox(height: 24),

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
                    children: [
                      // 1-Tap Sprint Tile
                      if (feed.dueStudyDecks.any((d) => d.totalCards > 0)) ...[
                        _NextBestActionCard(
                          topDeck: feed.dueStudyDecks.firstWhere((d) => d.totalCards > 0),
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
                            decks: feed.dueStudyDecks.skip(1).toList(),
                          ),
                        ],
                      ] else ...[
                        _EmptyStudyDecksCard(l10n: context.l10n),
                      ],
                      const SizedBox(height: 24),

                      // Curated Courses Repository
                      if (feed.curatedCourses.isNotEmpty)
                        CuratedCourseCarousel(courses: feed.curatedCourses)
                      else
                        _EmptyCoursesCard(l10n: context.l10n),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Workstation Telemetry & Toolbox Column (flex: 5)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Real-time Cohort Presence
                      _StudyCirclePodPulseCard(targetTrack: targetTrack),
                      const SizedBox(height: 20),

                      // Retention Heatmap & Mastery Matrix
                      RetentionHeatMapWidget(analytics: feed.analyticsSummary),
                      const SizedBox(height: 20),

                      // Speed Dial / Action Toolbox
                      const QuickActionSpeedDial(),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
            return FsrsReviewDeckCard(deck: decks[index]);
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
                  colors.primary.withAlpha(isDark ? (isHovered ? 75 : 55) : (isHovered ? 35 : 25)),
                  colors.syllabotAccent.withAlpha(isDark ? (isHovered ? 55 : 40) : (isHovered ? 25 : 18)),
                ],
              ),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isHovered
                    ? colors.primary.withAlpha(isDark ? 140 : 100)
                    : colors.primary.withAlpha(isDark ? 90 : 60),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? (isHovered ? 40 : 25) : (isHovered ? 20 : 10)),
                  blurRadius: isHovered ? 14 : 10,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final trackLabel = (targetTrack != null && targetTrack!.trim().isNotEmpty)
        ? l10n.podSuffix(targetTrack!)
        : l10n.studyCirclePod;

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            unawaited(context.navigateTo(const CommunityHubRoute()));
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(isHovered ? 180 : 150)
                  : colors.surfacePrimary,
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isHovered
                    ? colors.syllabotAccent.withAlpha(isDark ? 120 : 80)
                    : colors.surfaceBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.syllabotAccent.withAlpha(isDark ? 20 : 10),
                  blurRadius: isHovered ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Live pulsing dot indicator
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.success.withAlpha(140),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.podPulseTitle,
                      style: typography.caption.bold.copyWith(
                        color: colors.syllabotAccent,
                        fontSize: 10.5,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      trackLabel,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PodMetricChip(
                        icon: Icons.group_rounded,
                        value: '4/6',
                        label: l10n.activeToday,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PodMetricChip(
                        icon: Icons.timer_outlined,
                        value: '185m',
                        label: l10n.groupFocus,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PodMetricChip(
                        icon: Icons.bolt_rounded,
                        value: '+250',
                        label: l10n.podKarma,
                      ),
                    ),
                  ],
                ),
              ],
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
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(180)
            : colors.surfaceSecondary.withAlpha(130),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: colors.syllabotAccent),
              const SizedBox(width: 4),
              Text(
                value,
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
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
              color: colors.textSecondary,
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
        border: Border.all(
          color: colors.warning.withAlpha(isDark ? 90 : 60),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.warning.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.healing_rounded,
              color: colors.warning,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.mediumImpact());
              unawaited(
                context.router.push(
                  StudySessionRoute(deckId: deck.id),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warning,
                borderRadius: AppRadius.radiusCard,
              ),
              child: Text(
                l10n.triageTenAction,
                style: typography.caption.bold.copyWith(
                  color: colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
