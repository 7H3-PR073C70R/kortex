import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Reads the platform's reduced-motion preference.
bool quizReduceMotion(BuildContext context) {
  return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Direction a staggered entrance travels from.
enum QuizEntranceAxis {
  up(Offset(0, 1)),
  right(Offset(1, 0));

  const QuizEntranceAxis(this.direction);

  final Offset direction;
}

/// Fades and lifts a child into place, offset in time with its siblings.
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
