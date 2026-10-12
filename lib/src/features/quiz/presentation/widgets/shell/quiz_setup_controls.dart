import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Group heading for the pre-quiz setup sheets.
///
/// Controls are grouped by intent rather than listed flat, so the decision
/// reads as three small questions instead of one long form.
class QuizSectionLabel extends StatelessWidget {
  const QuizSectionLabel({required this.label, this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: typography.caption.bold.copyWith(
              color: colors.textMuted,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Large tappable choice card used for the practice-versus-exam decision.
class QuizChoiceCard extends StatelessWidget {
  const QuizChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.accentColor,
    this.reduceMotion = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final accent = accentColor ?? colors.primary;

    return ShrinkableButton(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withAlpha(isDark ? 46 : 24)
              : (isDark ? colors.surfaceSecondary : colors.cardBackground),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected ? accent : colors.surfaceBorder,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withAlpha(isDark ? 70 : 36)
                    : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? accent : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: typography.footnote.bold.copyWith(
                            color: selected ? accent : colors.textPrimary,
                          ),
                        ),
                      ),
                      AnimatedScale(
                        scale: selected ? 1 : 0,
                        duration: reduceMotion
                            ? Duration.zero
                            : AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
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

/// Modes available when starting a quiz or past paper session.
enum QuizPracticeMode { practice, exam, millionaire }

/// Segmented mode selector for pre-quiz configuration sheets.
///
/// Designed to replace cramped, verbose cards with an accessible, responsive
/// 3-way toggle that leaves ample screen breathing room.
class QuizModeSegmentedControl extends StatelessWidget {
  const QuizModeSegmentedControl({
    required this.currentMode,
    required this.onModeSelected,
    this.reduceMotion = false,
    super.key,
  });

  final QuizPracticeMode currentMode;
  final ValueChanged<QuizPracticeMode> onModeSelected;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 100),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuizModeSegmentItem(
              title: 'Practice',
              icon: Icons.school_outlined,
              isSelected: currentMode == QuizPracticeMode.practice,
              accentColor: colors.primary,
              reduceMotion: reduceMotion,
              onTap: () {
                AppFeedback.light();
                onModeSelected(QuizPracticeMode.practice);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _QuizModeSegmentItem(
              title: 'Exam',
              icon: Icons.timer_outlined,
              isSelected: currentMode == QuizPracticeMode.exam,
              accentColor: colors.primary,
              reduceMotion: reduceMotion,
              onTap: () {
                AppFeedback.light();
                onModeSelected(QuizPracticeMode.exam);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _QuizModeSegmentItem(
              title: 'Millionaire',
              icon: Icons.workspace_premium_rounded,
              isSelected: currentMode == QuizPracticeMode.millionaire,
              accentColor: colors.warning,
              reduceMotion: reduceMotion,
              onTap: () {
                AppFeedback.light();
                onModeSelected(QuizPracticeMode.millionaire);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizModeSegmentItem extends StatelessWidget {
  const _QuizModeSegmentItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.reduceMotion = false,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      semanticLabel: '$title mode',
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected ? accentColor : colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withAlpha(isDark ? 60 : 35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.white : colors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic single-line caption displaying the selected mode's rules.
class QuizModeDescription extends StatelessWidget {
  const QuizModeDescription({
    required this.mode,
    this.reduceMotion = false,
    super.key,
  });

  final QuizPracticeMode mode;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final (icon, text, color) = switch (mode) {
      QuizPracticeMode.millionaire => (
          Icons.workspace_premium_rounded,
          '12-tier challenge ladder with lifelines • Fixed 12 questions',
          colors.warning,
        ),
      QuizPracticeMode.exam => (
          Icons.timer_outlined,
          'Timed exam simulation (1 min / question) • Score at end',
          colors.primary,
        ),
      QuizPracticeMode.practice => (
          Icons.school_outlined,
          'Study mode • Instant feedback & explanations as you go',
          colors.primary,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notice banner indicating locked question count in Millionaire mode.
class QuizMillionaireNotice extends StatelessWidget {
  const QuizMillionaireNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.warning.withAlpha(isDark ? 30 : 18),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.warning.withAlpha(isDark ? 80 : 50)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 17,
            color: colors.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '12 Questions · Fixed ladder',
              style: typography.caption.bold.copyWith(
                color: colors.warning,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
