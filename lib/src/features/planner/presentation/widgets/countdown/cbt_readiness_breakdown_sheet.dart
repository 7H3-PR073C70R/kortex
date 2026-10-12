import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Modal side-drawer or bottom sheet displaying the granular formula weights
/// and diagnostic mock launcher for an exam's CBT readiness score.
abstract final class CbtReadinessBreakdownSheet {
  static void show(
    BuildContext context, {
    required ExamEventEntity exam,
    required CbtReadinessResult readiness,
  }) {
    final neural = context.neural;
    final typography = context.typography;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    unawaited(
      AppAdaptiveSheet.showSideDrawer<void>(
        context: context,
        drawerWidth: 500,
        builder: (sheetContext) {
          return ClipRRect(
            borderRadius: isDesktop
                ? const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.dialog),
                  )
                : const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: isDesktop ? double.infinity : null,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: neural.obsidian900.withAlpha(245),
                  borderRadius: isDesktop
                      ? const BorderRadius.horizontal(
                          left: Radius.circular(AppRadius.dialog),
                        )
                      : const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.dialog),
                        ),
                  border: Border.all(
                    color: readiness.statusColor.withAlpha(90),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDesktop) ...[
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: neural.slate400,
                            ),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                      ],
                      if (!isDesktop) ...[
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: neural.slate400.withAlpha(120),
                            borderRadius:
                                BorderRadius.circular(AppRadius.micro),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Score Ring Header
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: readiness.statusColor.withAlpha(25),
                          border: Border.all(
                            color: readiness.statusColor,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${readiness.scorePercent}%',
                            style: typography.title2.bold.copyWith(
                              color: readiness.statusColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        '${exam.examName} CBT Readiness',
                        style: typography.title3.bold.copyWith(
                          color: neural.slate100,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${readiness.statusLabel}',
                        textAlign: TextAlign.center,
                        style: typography.footnote.regular.copyWith(
                          color: readiness.statusColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Formula Weights Breakdown
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
                            Text(
                              'Readiness Index Model Weights',
                              style: typography.caption.bold.copyWith(
                                color: neural.amber300,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildWeightRow(
                              context,
                              icon: Icons.psychology_rounded,
                              label: 'Flashcard Memory Retention (50%)',
                              value: '86%',
                              color: neural.emerald400,
                            ),
                            const SizedBox(height: 8),
                            _buildWeightRow(
                              context,
                              icon: Icons.quiz_rounded,
                              label: 'CBT Mock Exam Average (25%)',
                              value: '80%',
                              color: neural.amber400,
                            ),
                            const SizedBox(height: 8),
                            _buildWeightRow(
                              context,
                              icon: Icons.timer_rounded,
                              label: 'Target Date Proximity (25%)',
                              value: '${exam.daysRemaining} days left',
                              color: neural.slate300,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: readiness.statusColor,
                            foregroundColor: neural.obsidian950,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.badge),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(
                              context.router.push(
                                MockExamLobbyRoute(
                                  examId: exam.id,
                                  examName: exam.examName,
                                  subjectTrack: exam.subjectTrack,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            'Launch CBT Diagnostic Mock',
                            style: typography.callout.bold.copyWith(
                              color: neural.obsidian950,
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
        },
      ),
    );
  }

  static Widget _buildWeightRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final neural = context.neural;
    final typography = context.typography;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: typography.caption.medium.copyWith(
              color: neural.slate200,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: typography.caption.bold.copyWith(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
