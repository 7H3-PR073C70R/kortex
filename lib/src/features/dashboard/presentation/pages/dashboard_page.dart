import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curated_course_carousel.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/quick_action_speed_dial.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/retention_heat_map_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/sm2_review_deck_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/syllabot_quick_prompt_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class DashboardPage extends HookWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>.value(
          value: locator<DashboardBloc>()..add(const DashboardStarted()),
        ),
        BlocProvider<CramPlannerCubit>(
          create: (_) {
            final cubit = locator<CramPlannerCubit>();
            unawaited(cubit.loadExams());
            return cubit;
          },
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

        if (isNewlyRegistered && !hasSeenWelcome && context.mounted) {
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
                    storage.deletePreference(
                      key: PrefKeys.isNewlyRegistered,
                    ),
                  );
                },
              ),
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
                context.read<DashboardBloc>().add(const DashboardRefreshed());
                Timer(const Duration(milliseconds: 600), completer.complete);
                return completer.future;
              },
              color: colors.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isExpanded = constraints.maxWidth >= 1024;
                  final isMedium = constraints.maxWidth >= 600 && !isExpanded;

                  if (isExpanded) {
                    return _ExpandedDashboardLayout(
                      feed: feed,
                      userName: userName,
                      userPhotoUrl: userPhotoUrl,
                    );
                  } else if (isMedium) {
                    return _MediumDashboardLayout(
                      feed: feed,
                      userName: userName,
                      userPhotoUrl: userPhotoUrl,
                    );
                  } else {
                    return _CompactDashboardLayout(
                      feed: feed,
                      userName: userName,
                      userPhotoUrl: userPhotoUrl,
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
        const SizedBox(height: 18),

        // 2. Syllabot Insight Pill Skeleton
        const ShimmerPlaceholder(height: 38, borderRadius: 12),
        const SizedBox(height: 10),

        // 3. Prompt Bar Skeleton
        const ShimmerPlaceholder(height: 52, borderRadius: 24),
        const SizedBox(height: 18),

        // 4. Hero Card / Exam Countdown Skeleton
        const ShimmerPlaceholder(height: 130, borderRadius: 22),
        const SizedBox(height: 20),

        // 5. Quick Actions Speed Dial Skeleton
        const ShimmerPlaceholder(height: 48, borderRadius: 22),
        const SizedBox(height: 24),

        // 6. Curated Courses Skeleton
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
        const SizedBox(height: 24),

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
  });

  final DashboardFeedEntity feed;
  final String? userName;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // 1. Header Profile & Streak Bar
        HeaderProfileBar(
          analytics: feed.analyticsSummary,
          isProfileUncalibrated: feed.isProfileUncalibrated,
          userName: userName,
          userPhotoUrl: userPhotoUrl,
        ),
        const SizedBox(height: 18),

        // 2. Syllabot Floating Prompt Bar

        // 3. Dynamic Focus Hero Section (Exam Banner or Top Due Deck)
        const ExamCountdownBanner(),
        if (feed.dueStudyDecks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Sm2ReviewDeckCard(
            deck: feed.dueStudyDecks.first,
            isHero: true,
          ),
        ] else ...[
          const SizedBox(height: 16),
          _EmptyStudyDecksCard(l10n: l10n),
        ],
        const SizedBox(height: 20),

        // 4. Quick Action Speed Dial Bar
        const QuickActionSpeedDial(),
        const SizedBox(height: 24),

        // 5. Curated Course Carousel
        if (feed.curatedCourses.isNotEmpty) ...[
          CuratedCourseCarousel(courses: feed.curatedCourses),
          const SizedBox(height: 24),
        ] else ...[
          _EmptyCoursesCard(l10n: l10n),
          const SizedBox(height: 24),
        ],

        // 6. Active Recall SM-2 Review Queue (Remaining Decks)
        if (feed.dueStudyDecks.length > 1) ...[
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
          ...feed.dueStudyDecks.skip(1).map((deck) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Sm2ReviewDeckCard(deck: deck),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 7. Retention Heat Map & Stats
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(140)
              : colors.surfacePrimary.withAlpha(210),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.success.withAlpha(isDark ? 80 : 50),
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
                    'All caught up!',
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No active-recall cards due for review today. Keep it up!',
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
      onTap: () {
        unawaited(
          context.router.push(const OnboardingCalibrationRoute()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary.withAlpha(210),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 80 : 50),
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
                      'Curate Your Courses',
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to set up your subjects and track '
                      'your syllabus progress.',
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

/// Medium Viewport (600dp - 1024dp - Tablet) Two-Column Layout
class _MediumDashboardLayout extends StatelessWidget {
  const _MediumDashboardLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
  });

  final DashboardFeedEntity feed;
  final String? userName;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 18),
        const ExamCountdownBanner(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  SyllabotQuickPromptBar(
                    insightText: feed.syllabotDailyInsight,
                  ),
                  const SizedBox(height: 16),
                  if (feed.dueStudyDecks.isNotEmpty)
                    Sm2ReviewDeckCard(
                      deck: feed.dueStudyDecks.first,
                      isHero: true,
                    ),
                  const SizedBox(height: 16),
                  const QuickActionSpeedDial(),
                  const SizedBox(height: 20),
                  CuratedCourseCarousel(courses: feed.curatedCourses),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Column
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  RetentionHeatMapWidget(analytics: feed.analyticsSummary),
                  const SizedBox(height: 16),
                  ...feed.dueStudyDecks.skip(1).map((deck) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Sm2ReviewDeckCard(deck: deck),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Expanded Viewport (>= 1024dp - Desktop/Web) Responsive Dashboard
class _ExpandedDashboardLayout extends StatelessWidget {
  const _ExpandedDashboardLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
  });

  final DashboardFeedEntity feed;
  final String? userName;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center Primary Workspace (720dp)
            Expanded(
              flex: 6,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(32, 24, 20, 100),
                children: [
                  HeaderProfileBar(
                    analytics: feed.analyticsSummary,
                    isProfileUncalibrated: feed.isProfileUncalibrated,
                    userName: userName,
                    userPhotoUrl: userPhotoUrl,
                  ),
                  const SizedBox(height: 20),
                  const ExamCountdownBanner(),
                  const SizedBox(height: 20),
                  SyllabotQuickPromptBar(
                    insightText: feed.syllabotDailyInsight,
                  ),
                  const SizedBox(height: 20),
                  if (feed.dueStudyDecks.isNotEmpty)
                    Sm2ReviewDeckCard(
                      deck: feed.dueStudyDecks.first,
                      isHero: true,
                    ),
                  const SizedBox(height: 20),
                  const QuickActionSpeedDial(),
                  const SizedBox(height: 24),
                  CuratedCourseCarousel(courses: feed.curatedCourses),
                ],
              ),
            ),

            // Right Utility Panel (Stats & Extra Decks)
            Expanded(
              flex: 4,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 32, 100),
                children: [
                  RetentionHeatMapWidget(analytics: feed.analyticsSummary),
                  const SizedBox(height: 20),
                  ...feed.dueStudyDecks.skip(1).map((deck) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Sm2ReviewDeckCard(deck: deck),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
