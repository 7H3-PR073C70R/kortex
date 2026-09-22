import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

// Shared chrome and motion primitives for the quiz flow.
//
// Everything here obeys the app motion contract: `AppMotion` curves only,
// no ease-in, sub-300ms transitions, and a bypass when the platform asks for
// reduced motion. Pages compose these instead of re-drawing progress bars,
// banners and empty states by hand, so the quiz feels like one product.

/// Reads the platform's reduced-motion preference.
bool quizReduceMotion(BuildContext context) {
  return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Direction a staggered entrance travels from.
enum QuizEntranceAxis {
  up(Offset(0, 1)),
  right(Offset(1, 0))
  ;

  const QuizEntranceAxis(this.direction);

  final Offset direction;
}

/// Fades and lifts a child into place, offset in time with its siblings.
///
/// This is the app's signature staggered entrance, reused across the quiz
/// workspace, results, palettes and question lists so screens assemble
/// themselves in a readable order instead of appearing all at once.
class QuizStaggeredFade extends StatelessWidget {
  const QuizStaggeredFade({
    required this.child,
    this.index = 0,
    this.distance = 12,
    this.axis = QuizEntranceAxis.up,
    this.reduceMotion = false,
    super.key,
  });

  final Widget child;

  /// Position in the sequence. Later indices land later.
  final int index;

  /// How far the child travels while it fades in.
  final double distance;

  /// Direction of travel. [QuizEntranceAxis.right] reads as "next question".
  final QuizEntranceAxis axis;

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;

    return TweenAnimationBuilder<double>(
      key: ValueKey('$index-${axis.name}'),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.standard + AppMotion.staggerDelay * index,
      curve: AppMotion.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: axis.direction * (1 - t) * distance,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Thin, animated progress rail used at the top of every quiz screen.
class QuizProgressBar extends StatelessWidget {
  const QuizProgressBar({
    required this.value,
    this.color,
    this.height = 3,
    this.reduceMotion = false,
    super.key,
  });

  final double value;
  final Color? color;
  final double height;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.micro / 2),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: colors.surfaceBorder),
            ),
            AnimatedFractionallySizedBox(
              duration: reduceMotion ? Duration.zero : AppMotion.standard,
              curve: AppMotion.easeOutCubic,
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tone of an inline banner. Tone drives color only; meaning is always in text.
enum QuizBannerTone { info, success, warning, tutor }

/// Single contextual banner slot.
///
/// Only one of these shows at a time above the question, so a student never
/// stacks three notices fighting for the same attention.
class QuizInlineBanner extends StatelessWidget {
  const QuizInlineBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = QuizBannerTone.info,
    this.actionLabel,
    this.onAction,
    this.reduceMotion = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final QuizBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool reduceMotion;

  Color _accent(AppThemeColorsExtension colors) {
    return switch (tone) {
      QuizBannerTone.info => colors.primary,
      QuizBannerTone.success => colors.success,
      QuizBannerTone.warning => colors.warning,
      QuizBannerTone.tutor => colors.syllabotAccent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final accent = _accent(colors);

    final banner = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withAlpha(isDark ? 40 : 24),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.caption.bold.copyWith(color: accent),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            ShrinkableButton(
              onTap: onAction,
              semanticLabel: actionLabel,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  actionLabel!,
                  style: typography.caption.bold.copyWith(color: colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: QuizStaggeredFade(reduceMotion: reduceMotion, child: banner),
    );
  }
}

/// Whether the staged practice answer was right.
enum QuizVerdict { correct, incorrect }

/// Calm, inline answer feedback.
///
/// Replaces the old "everything is a modal" approach: the verdict slides up
/// under the options, states the answer in plain words, and offers the
/// explanation plus one optional route to the class.
class QuizVerdictPanel extends StatelessWidget {
  const QuizVerdictPanel({
    required this.verdict,
    required this.question,
    this.hintText,
    this.askClassLabel,
    this.onAskClass,
    this.reduceMotion = false,
    super.key,
  });

  final QuizVerdict verdict;
  final QuizQuestionEntity question;

  /// Shown after a miss, when a hint was on the table for this question.
  final String? hintText;
  final String? askClassLabel;
  final VoidCallback? onAskClass;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isCorrect = verdict == QuizVerdict.correct;
    final accent = isCorrect ? colors.success : colors.warning;

    return QuizStaggeredFade(
      reduceMotion: reduceMotion,
      distance: 16,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: accent.withAlpha(isDark ? 40 : 22),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: accent.withAlpha(100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.history_toggle_off_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCorrect
                        ? 'Nice, you got it'
                        : 'Correct answer: ${question.correctAnswer}',
                    style: typography.footnote.bold.copyWith(color: accent),
                  ),
                ),
              ],
            ),
            if (question.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              LatexRichViewer(
                text: question.explanation,
                style: typography.footnote.regular.copyWith(
                  color: colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
            if (!isCorrect && hintText != null) ...[
              const SizedBox(height: 8),
              Text(
                hintText!,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (!isCorrect &&
                question.latexFormula != null &&
                question.latexFormula!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              LatexFormulaBlock(formula: question.latexFormula!),
            ],
            if (!isCorrect && onAskClass != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onAskClass,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    askClassLabel ?? 'Ask the class about this',
                    style: typography.caption.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain-language empty, error and dead-end state used across the quiz flow.
class QuizEmptyState extends StatelessWidget {
  const QuizEmptyState({
    required this.headline,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.tone = QuizBannerTone.info,
    super.key,
  });

  final String headline;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final QuizBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final accent = switch (tone) {
      QuizBannerTone.warning => colors.error,
      _ => colors.primary,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withAlpha(context.isDarkMode ? 40 : 22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: typography.callout.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Compact count readout used in the palette and results headers.
class QuizStatChip extends StatelessWidget {
  const QuizStatChip({
    required this.label,
    required this.value,
    required this.color,
    this.reduceMotion = false,
    this.staggerIndex = 0,
    super.key,
  });

  final String label;
  final String value;
  final Color color;
  final bool reduceMotion;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return QuizStaggeredFade(
      reduceMotion: reduceMotion,
      index: staggerIndex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 38 : 20),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: typography.title3.bold.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for topic and mode context labels.
class QuizTagPill extends StatelessWidget {
  const QuizTagPill({
    required this.label,
    required this.color,
    this.icon,
    this.maxWidth,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 44 : 22),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.bold.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
