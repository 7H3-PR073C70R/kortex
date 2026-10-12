import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Slow breathing dot for the "studying with cohort" presence pill —
/// a quiet liveness signal, frozen under reduced motion.
class LiveCohortDot extends StatefulWidget {
  const LiveCohortDot({super.key});

  @override
  State<LiveCohortDot> createState() => _LiveCohortDotState();
}

class _LiveCohortDotState extends State<LiveCohortDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success,
        ),
      ),
    );
  }
}

/// Contextual In-Session Cram Banner (Phase 1 Pillar 2).
class CramSessionBanner extends StatelessWidget {
  const CramSessionBanner({
    required this.daysUntilExam,
    super.key,
  });

  final int daysUntilExam;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isCrunch = daysUntilExam <= 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.warning.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 15,
              color: colors.warning,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCrunch
                      ? 'Imminent Assessment Crunch'
                      : 'Milestone Crunch: $daysUntilExam days remaining',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  isCrunch
                      ? 'Intervals condensed to 24h for acute recall before your test.'
                      : 'Review intervals adjusted so cards stay fresh in your memory before exam day.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.badge),
              border: Border.all(
                color: colors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Clamped',
              style: typography.caption.bold.copyWith(
                color: colors.warning,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Control bar displaying cohort study pulse and Bionic reading toggle.
class StudyCohortBionicBar extends StatelessWidget {
  const StudyCohortBionicBar({
    required this.isBionicEnabled,
    required this.onToggleBionic,
    super.key,
  });

  final bool isBionicEnabled;
  final VoidCallback onToggleBionic;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(
              isDark ? 30 : 15,
            ),
            borderRadius: BorderRadius.circular(
              AppRadius.card,
            ),
            border: Border.all(
              color: colors.primary.withAlpha(40),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiveCohortDot(),
              const SizedBox(width: 6),
              Text(
                'Studying with cohort',
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          toggled: isBionicEnabled,
          label: 'Bionic Focus',
          child: ShrinkableButton(
            onTap: () {
              AppFeedback.selection();
              onToggleBionic();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isBionicEnabled
                    ? colors.primary.withAlpha(
                        isDark ? 60 : 35,
                      )
                    : colors.surfaceSecondary.withAlpha(
                        isDark ? 90 : 130,
                      ),
                borderRadius: BorderRadius.circular(
                  AppRadius.card,
                ),
                border: Border.all(
                  color: isBionicEnabled
                      ? colors.primary
                      : colors.surfaceBorder.withAlpha(60),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 13,
                    color: isBionicEnabled
                        ? colors.primary
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Bionic Focus',
                    style: typography.caption.bold.copyWith(
                      color: isBionicEnabled
                          ? colors.primary
                          : colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
