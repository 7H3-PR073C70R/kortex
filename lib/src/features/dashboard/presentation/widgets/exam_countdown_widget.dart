import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class ExamCountdownWidget extends StatelessWidget {
  const ExamCountdownWidget({
    required this.countdown,
    super.key,
  });

  final ExamCountdownEntity countdown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final syllabusPercent = (countdown.syllabusProgress * 100).toInt();

    return Semantics(
      container: true,
      label: '${countdown.examName}. '
          '${l10n.dashboardDaysLeft(countdown.daysRemaining)}. '
          '${l10n.dashboardSyllabusMastery}: $syllabusPercent%.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withAlpha(isDark ? 55 : 30),
                  colors.syllabotAccent.withAlpha(isDark ? 35 : 15),
                  if (isDark)
                    colors.surfaceSecondary.withAlpha(200)
                  else
                    colors.surfacePrimary.withAlpha(235),
                ],
              ),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 130 : 90),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 60 : 25),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Badge & Countdown Ticker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(80),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        countdown.badgeTitle,
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    // Countdown Day Orb
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withAlpha(
                          isDark ? 50 : 25,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF97316).withAlpha(120),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            size: 14,
                            color: Color(0xFFF97316),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n.dashboardDaysLeft(countdown.daysRemaining),
                            style: typography.caption.bold.copyWith(
                              color: isDark
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFFC2410C),
                              fontSize: 11.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Exam Name
                Text(
                  countdown.examName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 17.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),

                // Subject track
                Text(
                  countdown.subjectTrack,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.footnote.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Syllabus Coverage Metric
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.dashboardSyllabusMastery,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      l10n.dashboardSyllabusPercentComplete(syllabusPercent),
                      style: typography.footnote.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 7,
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(60)
                        : colors.surfaceBorder.withAlpha(120),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor:
                              countdown.syllabusProgress.clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.primary,
                                  colors.syllabotAccent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Primary CTA: Launch Mock Simulator
                Semantics(
                  button: true,
                  label: l10n.dashboardLaunchMockSimulatorSemantics(
                    countdown.examName,
                  ),
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        context.router.push(
                          MockExamLobbyRoute(
                            examId: countdown.id,
                            examName: countdown.examName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withAlpha(210),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(80),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.dashboardLaunchMockSimulator(
                              countdown.completedMocksCount,
                              countdown.totalMockPapersAvailable,
                            ),
                            style: typography.caption.bold.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
