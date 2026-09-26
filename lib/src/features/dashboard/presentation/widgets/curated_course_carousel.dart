import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module_quick_sheet.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Repository card accent pair (base + chip text + label text).
class _RepoAccent {
  const _RepoAccent({
    required this.base,
    required this.chip,
    required this.text,
  });

  final Color base;
  final Color chip;
  final Color text;
}

class CuratedCourseCarousel extends StatelessWidget {
  const CuratedCourseCarousel({
    required this.courses,
    super.key,
  });

  final List<CuratedCourseEntity> courses;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    if (courses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dashboardCuratedCourses,
            style: typography.callout.bold.copyWith(
              color: neural.slate100,
              fontSize: 14,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          ShrinkableButton(
            onTap: () async {
              final result = await context.router.push(CurateCoursesRoute());
              if (result == true && context.mounted) {
                context.read<DashboardBloc>().add(const DashboardRefreshed());
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: neural.glassPanel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: neural.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: neural.emerald.withAlpha(26),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          color: neural.emerald400,
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
                                color: neural.slate100,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.curateCoursesSubtitle,
                              style: typography.footnote.regular.copyWith(
                                color: neural.slate400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: neural.slate400,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: title + See All link + Manage button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                l10n.dashboardCuratedCourses,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.callout.bold.copyWith(
                  color: neural.slate100,
                  fontSize: 14,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "See All (N)" — plain emerald text link per design
                ShrinkableButton(
                  onTap: () {
                    AppFeedback.light();
                    unawaited(
                      context.router.push(const AllCuratedCoursesRoute()),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All (${courses.length})',
                        style: typography.caption.semiBold.copyWith(
                          color: neural.emerald400,
                          fontSize: 12,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: neural.emerald400,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // "Manage" — obsidian-850 bordered chip
                ShrinkableButton(
                  onTap: () async {
                    AppFeedback.light();
                    final result = await context.router.push(
                      CurateCoursesRoute(
                        initialEnrolledIds: courses.map((c) => c.id).toList(),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<DashboardBloc>().add(
                        const DashboardRefreshed(),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: neural.obsidian850,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: neural.hairlineStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 12,
                          color: neural.slate400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Manage',
                          style: typography.caption.medium.copyWith(
                            color: neural.slate300,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Single horizontally scrollable row of repository cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = ((constraints.maxWidth - 12) / 2).clamp(
              150.0,
              200.0,
            );
            return SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: courses.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  child: _CourseCard(
                    course: courses[index],
                    accentIndex: index,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.accentIndex,
  });

  final CuratedCourseEntity course;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final accents = [
      _RepoAccent(
        base: neural.cyan,
        chip: neural.cyan300,
        text: neural.cyan400,
      ),
      _RepoAccent(
        base: neural.emerald,
        chip: neural.emerald300,
        text: neural.emerald400,
      ),
    ];
    final accent = accents[accentIndex % accents.length];

    // Query matching decks from DecksBloc if registered
    final allDecks = locator.isRegistered<DecksBloc>()
        ? locator<DecksBloc>().state.allDecks
        : const <DeckEntity>[];

    final matchingDecks = allDecks
        .where(
          (d) =>
              d.courseId == course.id ||
              (d.courseCode != null && d.courseCode == course.courseCode) ||
              d.subject.toLowerCase() == course.title.toLowerCase(),
        )
        .toList();

    final totalCards = matchingDecks.fold<int>(0, (s, d) => s + d.totalCards);
    final hasDecks = matchingDecks.isNotEmpty;
    final realCoverage = hasDecks
        ? (matchingDecks.fold<double>(0, (s, d) => s + d.masteryRate) /
                  matchingDecks.length)
              .clamp(0.0, 1.0)
        : 0.0;
    final coveragePercent = (realCoverage * 100).toInt();
    final deckCountText = hasDecks
        ? '${matchingDecks.length} ${matchingDecks.length == 1 ? 'Deck' : 'Decks'} • $totalCards Cards'
        : 'No study decks yet';

    return Semantics(
      button: true,
      label: '${course.courseCode} ${course.title}. $deckCountText.',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              unawaited(
                CourseModuleQuickSheet.show(context, course: course),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: neural.glassPanel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHovered
                          ? accent.base.withAlpha(102)
                          : neural.hairline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Code chip + Q-Bank badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: neural.obsidian800,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.base.withAlpha(51),
                                ),
                              ),
                              child: Text(
                                course.courseCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.code.bold.copyWith(
                                  color: accent.chip,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          if (course.hasActivePastPapers) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: neural.emerald.withAlpha(26),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: neural.emerald.withAlpha(51),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 10,
                                    color: neural.emerald400,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Q-Bank',
                                    style: typography.caption.medium.copyWith(
                                      color: neural.emerald400,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Course title
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typography.callout.bold.copyWith(
                          color: neural.slate100,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),

                      // Footer: deck count + coverage % over a hairline divider
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: neural.hairlineSoft),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    deckCountText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.caption.regular.copyWith(
                                      color: neural.slate400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$coveragePercent%',
                                  style: typography.code.bold.copyWith(
                                    color: accent.text,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: SizedBox(
                                height: 4,
                                child: ColoredBox(
                                  color: neural.obsidian800,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: realCoverage,
                                      child: ColoredBox(color: accent.base),
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
            ),
          );
        },
      ),
    );
  }
}
