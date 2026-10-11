import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

void showAnalyticsNeuralRepairSheet(
  BuildContext context,
  int day,
  double retrievability,
) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;
  final percent = (retrievability * 100).toInt();

  unawaited(
    AppAdaptiveSheet.showModal<void>(
      context: context,
      builder: (modalContext) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(modalContext);
        return Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: isDesktop
                    ? BorderRadius.circular(AppRadius.dialog)
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: colors.surfaceBorder),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDesktop) ...[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withAlpha(80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1-Tap Neural Repair (Day $day)',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Targeted memory reinforcement ($percent% recall chance)',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  NeuralRepairOptionTile(
                    icon: Icons.style_rounded,
                    title: 'Quick Flashcard Memory Refresh',
                    subtitle:
                        'Focus on due cards to strengthen memory retention',
                    color: colors.primary,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      try {
                        unawaited(
                          context.router.push(
                            const MainRoute(children: [DecksRoute()]),
                          ),
                        );
                      } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }
                    },
                  ),
                  const SizedBox(height: 10),
                  NeuralRepairOptionTile(
                    icon: Icons.quiz_rounded,
                    title: '10-Question Diagnostic Drill',
                    subtitle: 'Fast CBT mock quiz to lock in fading concepts',
                    color: colors.secondary,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      try {
                        unawaited(
                          context.router.push(PastQuestionsBoardRoute()),
                        );
                      } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }
                    },
                  ),
                  const SizedBox(height: 10),
                  NeuralRepairOptionTile(
                    icon: Icons.psychology_rounded,
                    title: 'Ask Syllabot AI Coach',
                    subtitle: 'Get a personalized 3-step study action plan',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      context.showSnackBar(
                        message:
                            'Syllabot: Analyzing Day $day memory decay. Focus 15 mins on Organic Chemistry mechanisms today!',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class NeuralRepairOptionTile extends StatelessWidget {
  const NeuralRepairOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary.withAlpha(120),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.surfaceBorder.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
