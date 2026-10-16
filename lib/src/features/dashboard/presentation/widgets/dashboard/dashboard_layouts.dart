import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness_gauge_section.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curated_course_carousel.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/daily_recall_status_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_empty_cards.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_next_best_action_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_quick_actions_grid.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_select_track_prompt_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_spaced_repetition_grid.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_study_debt_triage_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard_header_profile_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/fsrs_review_deck_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/quick_action_speed_dial.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/recent_deck_carousel.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/resume_active_cbt_exam_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/retention_heat_map_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/study_circle_pod_pulse_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';

/// Compact Viewport (< 600dp - Mobile) Layout
class DashboardCompactLayout extends StatelessWidget {
  const DashboardCompactLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
    this.targetTrack,
    super.key,
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
                DashboardHeaderProfileBar(
                  targetTrack: targetTrack,
                ),
                const SizedBox(height: 16),

                // Prompt track selection if not selected yet
                if (targetTrack == null || targetTrack!.trim().isEmpty) ...[
                  const DashboardSelectTrackPromptBanner(),
                  const SizedBox(height: 16),
                ],

                // 2. Exam Countdown Banner + Backlog Debt Triage
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  child: Column(
                    children: [
                      const ResumeActiveCbtExamBanner(),
                      if (feed.curatedCourses.isNotEmpty) ...[
                        ExamCountdownBanner(
                          key: AppTourKeys.countdownKey,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (heavyDebtDeck != null) ...[
                        DashboardStudyDebtTriageBanner(deck: heavyDebtDeck),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // 3. Daily Recall Status Banner ("All caught up!" / due-cards state)
                DailyRecallStatusBanner(
                  key: AppTourKeys.reviewQueueKey,
                  feed: feed,
                ),

                const SizedBox(height: 16),

                // 4. Quick Actions Grid (Upload Notes | Q-Bank | 1v1 Duel | New Deck)
                DashboardQuickActionsGrid(
                  key: AppTourKeys.quickActionsKey,
                ),
                const SizedBox(height: 16),

                // 5. Curated Course Repositories
                if (feed.curatedCourses.isNotEmpty) ...[
                  CuratedCourseCarousel(courses: feed.curatedCourses),
                  const SizedBox(height: 16),
                ] else ...[
                  DashboardEmptyCoursesCard(l10n: l10n),
                  const SizedBox(height: 16),
                ],

                // 6. Pod Pulse — Study Circle Co-presence
                StudyCirclePodPulseCard(targetTrack: targetTrack),
                const SizedBox(height: 16),

                // 7. CBT Readiness Score Progress Gauge
                CbtReadinessGaugeSection(
                  targetTrack: targetTrack,
                ),
                const SizedBox(height: 16),

                // 8. Retention Heat Map & Mastery Stats
                RetentionHeatMapWidget(analytics: feed.analyticsSummary),
              ]
              .animate(interval: 50.ms)
              .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuint),
    );
  }
}

/// Medium Viewport (600dp - 1023dp - Tablet) 2-Column Bento Layout
class DashboardMediumLayout extends StatelessWidget {
  const DashboardMediumLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
    this.targetTrack,
    super.key,
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
                DashboardHeaderProfileBar(
                  targetTrack: targetTrack,
                ),
                const SizedBox(height: 20),

                // Prompt track selection if not selected yet
                if (targetTrack == null || targetTrack!.trim().isEmpty) ...[
                  const DashboardSelectTrackPromptBanner(),
                  const SizedBox(height: 20),
                ],
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  child: Column(
                    children: [
                      const ResumeActiveCbtExamBanner(
                        margin: EdgeInsets.only(bottom: 20),
                      ),
                      if (feed.curatedCourses.isNotEmpty) ...[
                        ExamCountdownBanner(
                          key: AppTourKeys.countdownKey,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (heavyDebtDeck != null) ...[
                        DashboardStudyDebtTriageBanner(deck: heavyDebtDeck),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
                if (feed.dueStudyDecks.any((d) => d.totalCards > 0)) ...[
                  DashboardNextBestActionCard(
                    key: AppTourKeys.reviewQueueKey,
                    topDeck: feed.dueStudyDecks.firstWhere(
                      (d) => d.totalCards > 0,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Quick Actions, Active Recall, Curated Courses & Cohort Pulse)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QuickActionSpeedDial(
                            key: AppTourKeys.quickActionsKey,
                          ),
                          const SizedBox(height: 20),
                          if (feed.dueStudyDecks.isNotEmpty)
                            FsrsReviewDeckCard(
                              key: AppTourKeys.reviewQueueKey,
                              deck: feed.dueStudyDecks.first,
                              isHero: true,
                            )
                          else
                            DashboardEmptyStudyDecksCard(
                              key: AppTourKeys.reviewQueueKey,
                              l10n: context.l10n,
                            ),
                          const SizedBox(height: 20),
                          if (feed.dueStudyDecks.length > 1) ...[
                            RecentDeckCarousel(
                              decks: feed.dueStudyDecks.skip(1).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (feed.curatedCourses.isNotEmpty)
                            CuratedCourseCarousel(courses: feed.curatedCourses)
                          else
                            DashboardEmptyCoursesCard(l10n: context.l10n),
                          const SizedBox(height: 20),
                          StudyCirclePodPulseCard(
                            targetTrack: targetTrack,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right Column (CBT Readiness & Retention Analytics)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children:
                            [
                                  CbtReadinessGaugeSection(
                                    targetTrack: targetTrack,
                                  ),
                                  const SizedBox(height: 20),
                                  RetentionHeatMapWidget(
                                    analytics: feed.analyticsSummary,
                                  ),
                                ]
                                .animate(interval: 50.ms)
                                .fadeIn(
                                  duration: 380.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  curve: Curves.easeOutQuint,
                                ),
                      ),
                    ),
                  ],
                ),
              ]
              .animate(interval: 50.ms)
              .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuint),
    );
  }
}

/// Expanded Viewport (>= 1024dp - Desktop/Web) Asymmetric Bento Grid Workstation
class DashboardExpandedLayout extends StatelessWidget {
  const DashboardExpandedLayout({
    required this.feed,
    this.userName,
    this.userPhotoUrl,
    this.targetTrack,
    super.key,
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
                    DashboardHeaderProfileBar(
                      targetTrack: targetTrack,
                    ),
                    const SizedBox(height: 24),

                    // Prompt track selection if not selected yet
                    if (targetTrack == null || targetTrack!.trim().isEmpty) ...[
                      const DashboardSelectTrackPromptBanner(),
                      const SizedBox(height: 24),
                    ],

                    // 2. Urgent Callouts (with AnimatedSize for layout stability)
                    AnimatedSize(
                      alignment: Alignment.topCenter,
                      duration: AppMotion.standard,
                      curve: AppMotion.easeOutCubic,
                      child: Column(
                        children: [
                          const ResumeActiveCbtExamBanner(
                            margin: EdgeInsets.only(bottom: 20),
                          ),
                          if (feed.curatedCourses.isNotEmpty) ...[
                            ExamCountdownBanner(
                              key: AppTourKeys.countdownKey,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (heavyDebtDeck != null) ...[
                            DashboardStudyDebtTriageBanner(deck: heavyDebtDeck),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),

                    // 3. Asymmetric Bento Grid Workstation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Workstation Column (Quick Actions, Active Recall, Curated Courses & Cohort Pulse)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children:
                                [
                                      QuickActionSpeedDial(
                                        key: AppTourKeys.quickActionsKey,
                                      ),
                                      const SizedBox(height: 20),

                                      // 1-Tap Sprint Tile
                                      if (feed.dueStudyDecks.any(
                                        (d) => d.totalCards > 0,
                                      )) ...[
                                        DashboardNextBestActionCard(
                                          key: AppTourKeys.reviewQueueKey,
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
                                          key: AppTourKeys.reviewQueueKey,
                                          deck: feed.dueStudyDecks.first,
                                          isHero: true,
                                        ),
                                        if (feed.dueStudyDecks.length > 1) ...[
                                          const SizedBox(height: 20),
                                          DashboardDesktopSpacedRepetitionGrid(
                                            decks: feed.dueStudyDecks
                                                .skip(1)
                                                .toList(),
                                          ),
                                        ],
                                      ] else ...[
                                        DashboardEmptyStudyDecksCard(
                                          key: AppTourKeys.reviewQueueKey,
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
                                        DashboardEmptyCoursesCard(
                                          l10n: context.l10n,
                                        ),
                                      const SizedBox(height: 20),

                                      // Real-time Cohort Presence
                                      StudyCirclePodPulseCard(
                                        targetTrack: targetTrack,
                                      ),
                                    ]
                                    .animate(interval: 50.ms)
                                    .fadeIn(
                                      duration: 380.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .slideY(
                                      begin: 0.04,
                                      end: 0,
                                      curve: Curves.easeOutQuint,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Right Workstation Column (CBT Telemetry & Retention Heatmap)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children:
                                [
                                      // CBT Readiness Score Progress Gauge
                                      CbtReadinessGaugeSection(
                                        targetTrack: targetTrack,
                                      ),
                                      const SizedBox(height: 20),

                                      // Retention Heatmap & Mastery Matrix
                                      RetentionHeatMapWidget(
                                        analytics: feed.analyticsSummary,
                                      ),
                                    ]
                                    .animate(interval: 50.ms)
                                    .fadeIn(
                                      duration: 380.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .slideY(
                                      begin: 0.04,
                                      end: 0,
                                      curve: Curves.easeOutQuint,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ]
                  .animate(interval: 50.ms)
                  .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
                  .slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuint),
        ),
      ),
    );
  }
}
