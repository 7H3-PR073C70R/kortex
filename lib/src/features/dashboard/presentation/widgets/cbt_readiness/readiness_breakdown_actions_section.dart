import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';

/// Bottleneck diagnostics and action recommendation section for CBT readiness sheet.
class ReadinessBreakdownActionsSection extends StatelessWidget {
  const ReadinessBreakdownActionsSection({
    required this.readiness,
    required this.examTitle,
    super.key,
  });

  final CbtReadinessResult readiness;
  final String examTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Bottleneck Diagnostic
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfacePrimary.withAlpha(isDark ? 60 : 200),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(60),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: readiness.statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Primary Bottleneck Diagnostic',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                readiness.weakestAreaLabel.isNotEmpty
                    ? readiness.weakestAreaLabel
                    : 'Memory Retention Stability',
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Actionable Remediation
        Text(
          'RECOMMENDED ACTION',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(isDark ? 40 : 20),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.primary.withAlpha(80)),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  readiness.remediationSuggestion,
                  style: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bottom Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final rawWeakest = readiness.weakestAreaLabel;
                  final cleanSubject = rawWeakest.contains('(')
                      ? rawWeakest.split('(').first.trim()
                      : (rawWeakest.isNotEmpty
                          ? rawWeakest.trim()
                          : 'key concepts');
                  final prompt =
                      "Let's do an interactive study sprint for $cleanSubject to boost my $examTitle exam readiness. Please quiz me on high-yield syllabus topics and explain core concepts step-by-step.";
                  unawaited(
                    context.router.push(
                      SyllabotChatRoute(initialPrompt: prompt),
                    ),
                  );
                },
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: colors.primary,
                ),
                label: Text(
                  'AI Sprint',
                  style: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                child: Text(
                  'Done',
                  style: typography.body.medium.copyWith(
                    color: colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
