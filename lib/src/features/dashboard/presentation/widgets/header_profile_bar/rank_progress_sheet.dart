import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Shows an adaptive modal sheet detailing current academic rank, XP progression, and multipliers.
void showRankProgressSheet(
  BuildContext context,
  AnalyticsSummaryEntity analytics,
  dynamic authProfile,
) {
  final neural = context.neural;
  final typography = context.typography;

  final currentXp = analytics.xpPoints > 0 ? analytics.xpPoints : 3400;
  const targetXp = 5000;
  final progressRatio = (currentXp / targetXp).clamp(0.0, 1.0);
  final userLevel = (authProfile as dynamic)?.level ?? 1;

  unawaited(
    AppAdaptiveSheet.showModal<void>(
      context: context,
      builder: (sheetContext) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetContext);
        return Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ClipRRect(
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.dialog),
                    ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, isDesktop ? 24 : 16, 24, 32),
                  decoration: BoxDecoration(
                    color: neural.obsidian900.withAlpha(245),
                    borderRadius: isDesktop
                        ? BorderRadius.circular(AppRadius.dialog)
                        : const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.dialog),
                          ),
                    border: Border.all(
                      color: neural.amber.withAlpha(80),
                    ),
                    boxShadow: isDesktop
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isDesktop) ...[
                        // Handle
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: neural.slate400.withAlpha(120),
                            borderRadius: BorderRadius.circular(
                              AppRadius.micro,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Rank Badge Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              neural.amber400,
                              neural.amber,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: neural.amber.withAlpha(120),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 36,
                            color: neural.obsidian950,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        analytics.academicRank,
                        style: typography.title2.bold.copyWith(
                          color: neural.slate100,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: neural.emerald.withAlpha(30),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                          border: Border.all(
                            color: neural.emerald400.withAlpha(100),
                          ),
                        ),
                        child: Text(
                          'LEVEL $userLevel SCHOLAR',
                          style: typography.caption.bold.copyWith(
                            color: neural.emerald400,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress Bar Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: neural.obsidian850,
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                          border: Border.all(color: neural.hairlineStrong),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Next Rank: Master Scholar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.footnote.bold.copyWith(
                                      color: neural.slate200,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$currentXp / $targetXp XP',
                                  style: typography.footnote.bold.copyWith(
                                    color: neural.amber300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.micro,
                              ),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 8,
                                backgroundColor: neural.obsidian800,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  neural.amber400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Earn ${(targetXp - currentXp).clamp(0, targetXp)} more XP to rank up and unlock Advanced Socratic Drills!',
                              style: typography.caption.regular.copyWith(
                                color: neural.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Multipliers & Active Perks
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: neural.obsidian850,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.badge,
                                ),
                                border: Border.all(
                                  color: neural.amber.withAlpha(40),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                    color: neural.amber400,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '+15% XP Active Recall Multiplier',
                                      style: typography.caption.bold.copyWith(
                                        color: neural.slate200,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ShrinkableButton(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(
                              context.router.push(
                                AnalyticsDetailRoute(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [neural.amber400, neural.amber],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'View Full Analytics & Rank Badges',
                                style: typography.callout.bold.copyWith(
                                  color: neural.obsidian950,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
