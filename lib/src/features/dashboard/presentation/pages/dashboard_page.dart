import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curated_course_carousel.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/exam_countdown_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/quick_action_speed_dial.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/retention_heat_map_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/sm2_review_deck_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/syllabot_quick_prompt_bar.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class DashboardPage extends HookWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>(
          create: (_) => locator<DashboardBloc>()
            ..add(const DashboardStarted()),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
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
                          context
                              .read<DashboardBloc>()
                              .add(const DashboardStarted());
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
                              color: Colors.white,
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
                    return _ExpandedDashboardLayout(feed: feed);
                  } else if (isMedium) {
                    return _MediumDashboardLayout(feed: feed);
                  } else {
                    return _CompactDashboardLayout(feed: feed);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact Viewport (< 600dp) Single-Column Scroll
class _CompactDashboardLayout extends StatelessWidget {
  const _CompactDashboardLayout({required this.feed});

  final DashboardFeedEntity feed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isHighSchool = feed.isHighSchoolCandidate;

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
        ),
        const SizedBox(height: 18),

        // Exam Countdown & Dynamic Cram Planner Banner
        const ExamCountdownBanner(),
        const SizedBox(height: 18),

        // 2. Syllabot Floating Prompt Bar
        SyllabotQuickPromptBar(
          insightText: feed.syllabotDailyInsight,
        ),
        const SizedBox(height: 20),

        // 3. Adaptive Hero Section
        if (isHighSchool && feed.targetExamCountdown != null) ...[
          ExamCountdownWidget(countdown: feed.targetExamCountdown!),
          const SizedBox(height: 20),
        ] else if (feed.dueStudyDecks.isNotEmpty) ...[
          Sm2ReviewDeckCard(
            deck: feed.dueStudyDecks.first,
            isHero: true,
          ),
          const SizedBox(height: 20),
        ],

        // 4. Quick Action Speed Dial Bar
        const QuickActionSpeedDial(),
        const SizedBox(height: 24),

        // 5. Curated Course Carousel
        CuratedCourseCarousel(courses: feed.curatedCourses),
        const SizedBox(height: 24),

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
          ...feed.dueStudyDecks.skip(isHighSchool ? 0 : 1).map((deck) {
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

/// Medium Viewport (600dp - 1024dp - Tablet) Two-Column Layout
class _MediumDashboardLayout extends StatelessWidget {
  const _MediumDashboardLayout({required this.feed});

  final DashboardFeedEntity feed;

  @override
  Widget build(BuildContext context) {
    final isHighSchool = feed.isHighSchoolCandidate;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      children: [
        HeaderProfileBar(
          analytics: feed.analyticsSummary,
          isProfileUncalibrated: feed.isProfileUncalibrated,
        ),
        const SizedBox(height: 18),
        const ExamCountdownBanner(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  SyllabotQuickPromptBar(
                    insightText: feed.syllabotDailyInsight,
                  ),
                  const SizedBox(height: 16),
                  if (isHighSchool && feed.targetExamCountdown != null)
                    ExamCountdownWidget(countdown: feed.targetExamCountdown!)
                  else if (feed.dueStudyDecks.isNotEmpty)
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

/// Expanded Viewport (> 1024dp - Desktop/Web) Center Workspace + Right Utility Panel
class _ExpandedDashboardLayout extends StatelessWidget {
  const _ExpandedDashboardLayout({required this.feed});

  final DashboardFeedEntity feed;

  @override
  Widget build(BuildContext context) {
    final isHighSchool = feed.isHighSchoolCandidate;

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
                  ),
                  const SizedBox(height: 20),
                  SyllabotQuickPromptBar(
                    insightText: feed.syllabotDailyInsight,
                  ),
                  const SizedBox(height: 20),
                  if (isHighSchool && feed.targetExamCountdown != null)
                    ExamCountdownWidget(countdown: feed.targetExamCountdown!)
                  else if (feed.dueStudyDecks.isNotEmpty)
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
