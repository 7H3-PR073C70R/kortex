import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Where an option currently stands in the answer loop.
///
/// Keeping this explicit means the workspace, the duel arena and the tests all
/// describe the same thing the same way, instead of combining three booleans
/// and hoping the math lands on the right look.
enum McqOptionState {
  /// Untouched, tappable.
  idle,

  /// Chosen but not graded: a staged practice pick, or an exam answer that can
  /// still be changed before the student submits.
  selected,

  /// Graded and it was the right answer.
  correctReveal,

  /// Graded and it was the student's wrong pick.
  wrongReveal,

  /// Taken out of play (lifeline, or dimmed after the verdict).
  muted,
}

class McqOptionCard extends StatelessWidget {
  const McqOptionCard({
    required this.optionText,
    required this.index,
    required this.state,
    required this.onTap,
    this.reduceMotion = false,
    super.key,
  });

  /// Convenience mapping from raw session flags to an [McqOptionState].
  static McqOptionState resolveState({
    required bool isSelected,
    required bool isAnswered,
    required bool isCorrect,
    bool isEliminated = false,
  }) {
    if (isEliminated) return McqOptionState.muted;
    if (!isAnswered) {
      return isSelected ? McqOptionState.selected : McqOptionState.idle;
    }
    if (isCorrect) return McqOptionState.correctReveal;
    if (isSelected) return McqOptionState.wrongReveal;
    return McqOptionState.muted;
  }

  final String optionText;
  final int index;
  final McqOptionState state;
  final VoidCallback onTap;
  final bool reduceMotion;

  bool get _isInteractive =>
      state == McqOptionState.idle || state == McqOptionState.selected;

  String get _letterPrefix => String.fromCharCode(65 + index); // A, B, C, D

  String get _displayOptionText =>
      QuizContentSanitizer.cleanOptionText(optionText);

  String get _semanticsHint {
    return switch (state) {
      McqOptionState.correctReveal => 'Correct answer',
      McqOptionState.wrongReveal => 'Not quite, this was your answer',
      McqOptionState.selected => 'Selected, not checked yet',
      McqOptionState.muted => 'No longer available',
      McqOptionState.idle => 'Not selected',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final palette = _OptionPalette.resolve(
      state: state,
      colors: colors,
      isDark: isDark,
    );

    final card = PlatformHoverBuilder(
      isEnabled: _isInteractive,
      builder: (context, isHovered, child) {
        final hoverLift = _isInteractive && isHovered;
        return InkWell(
          onTap: _isInteractive ? onTap : null,
          borderRadius: AppRadius.radiusCard,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : AppMotion.standard,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hoverLift ? palette.hoverColor : palette.color,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: hoverLift ? palette.hoverBorder : palette.border,
                width: palette.borderWeight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(
                    hoverLift ? (isDark ? 45 : 16) : (isDark ? 25 : 6),
                  ),
                  blurRadius: hoverLift ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _LetterBadge(
                  letter: _letterPrefix,
                  state: state,
                  palette: palette,
                  reduceMotion: reduceMotion,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LatexRichViewer(
                    text: _displayOptionText,
                    style: typography.body.medium.copyWith(
                      color: palette.textColor,
                    ),
                  ),
                ),
                _TrailingMark(state: state, palette: palette),
              ],
            ),
          ),
        );
      },
    );

    return Semantics(
      button: true,
      enabled: _isInteractive,
      selected: state == McqOptionState.selected,
      label: 'Option $_letterPrefix: $_displayOptionText',
      hint: _semanticsHint,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: _RevealMotion(
          state: state,
          reduceMotion: reduceMotion,
          child: card,
        ),
      ),
    );
  }
}

/// Color + weight set for one visual state.
class _OptionPalette {
  const _OptionPalette({
    required this.color,
    required this.hoverColor,
    required this.border,
    required this.hoverBorder,
    required this.borderWeight,
    required this.badgeColor,
    required this.badgeBorder,
    required this.badgeTextColor,
    required this.accent,
    required this.textColor,
  });

  factory _OptionPalette.resolve({
    required McqOptionState state,
    required AppThemeColorsExtension colors,
    required bool isDark,
  }) {
    final base = _OptionPalette(
      color: isDark ? colors.surfaceSecondary : colors.cardBackground,
      hoverColor: isDark
          ? colors.surfaceSecondary.withAlpha(220)
          : colors.surfacePrimary,
      border: isDark
          ? colors.surfaceBorderHighlight.withAlpha(50)
          : colors.surfaceBorder,
      hoverBorder: colors.primary.withAlpha(isDark ? 140 : 100),
      borderWeight: 1,
      badgeColor: colors.surfaceSecondary,
      badgeBorder: colors.surfaceBorder,
      badgeTextColor: colors.textPrimary,
      accent: colors.textSecondary,
      textColor: colors.textPrimary,
    );

    return switch (state) {
      McqOptionState.idle => base,
      McqOptionState.selected => base._tinted(colors.primary, isDark),
      McqOptionState.correctReveal => base._tinted(colors.success, isDark),
      McqOptionState.wrongReveal => base._tinted(colors.error, isDark),
      McqOptionState.muted => base.copyWith(
        color: isDark ? colors.surfaceSecondary : colors.cardBackground,
        border: colors.surfaceBorder.withAlpha(70),
        badgeColor: colors.surfaceSecondary.withAlpha(90),
        badgeTextColor: colors.textMuted,
        textColor: colors.textMuted,
        accent: colors.textMuted,
      ),
    };
  }

  final Color color;
  final Color hoverColor;
  final Color border;
  final Color hoverBorder;
  final double borderWeight;
  final Color badgeColor;
  final Color badgeBorder;
  final Color badgeTextColor;
  final Color accent;
  final Color textColor;

  _OptionPalette _tinted(Color accent, bool isDark) {
    return copyWith(
      color: accent.withAlpha(isDark ? 50 : 20),
      hoverColor: accent.withAlpha(isDark ? 62 : 28),
      border: accent,
      hoverBorder: accent,
      borderWeight: 1.8,
      badgeColor: accent.withAlpha(isDark ? 75 : 35),
      badgeBorder: accent.withAlpha(130),
      badgeTextColor: accent,
      accent: accent,
    );
  }

  _OptionPalette copyWith({
    Color? color,
    Color? hoverColor,
    Color? border,
    Color? hoverBorder,
    double? borderWeight,
    Color? badgeColor,
    Color? badgeBorder,
    Color? badgeTextColor,
    Color? accent,
    Color? textColor,
  }) {
    return _OptionPalette(
      color: color ?? this.color,
      hoverColor: hoverColor ?? this.hoverColor,
      border: border ?? this.border,
      hoverBorder: hoverBorder ?? this.hoverBorder,
      borderWeight: borderWeight ?? this.borderWeight,
      badgeColor: badgeColor ?? this.badgeColor,
      badgeBorder: badgeBorder ?? this.badgeBorder,
      badgeTextColor: badgeTextColor ?? this.badgeTextColor,
      accent: accent ?? this.accent,
      textColor: textColor ?? this.textColor,
    );
  }
}

/// The A/B/C/D chip, which turns into a check once an answer is committed.
class _LetterBadge extends StatelessWidget {
  const _LetterBadge({
    required this.letter,
    required this.state,
    required this.palette,
    required this.reduceMotion,
  });

  final String letter;
  final McqOptionState state;
  final _OptionPalette palette;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final showCheck =
        state == McqOptionState.selected ||
        state == McqOptionState.correctReveal ||
        state == McqOptionState.wrongReveal;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppMotion.snappy,
      curve: AppMotion.easeOutCubic,
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.badgeColor,
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: palette.badgeBorder),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : AppMotion.snappy,
        switchInCurve: AppMotion.easeOutCubic,
        switchOutCurve: AppMotion.exitCurve,
        child: showCheck
            ? Icon(
                key: const ValueKey('check'),
                _checkIconFor(state),
                size: 16,
                color: palette.badgeTextColor,
              )
            : Text(
                key: const ValueKey('letter'),
                letter,
                style: typography.footnote.bold.copyWith(
                  color: palette.badgeTextColor,
                ),
              ),
      ),
    );
  }

  static IconData _checkIconFor(McqOptionState state) {
    return state == McqOptionState.wrongReveal
        ? Icons.close_rounded
        : Icons.check_rounded;
  }
}

/// Trailing confirmation mark, kept subtle so color does most of the talking.
class _TrailingMark extends StatelessWidget {
  const _TrailingMark({required this.state, required this.palette});

  final McqOptionState state;
  final _OptionPalette palette;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      McqOptionState.correctReveal => Icons.check_circle_rounded,
      McqOptionState.wrongReveal => Icons.cancel_rounded,
      _ => null,
    };
    if (icon == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, color: palette.accent, size: 20),
    );
  }
}

/// One-shot entrance choreography for graded states.
///
/// A miss gets a short lateral nudge, a hit gets a soft pop. Both are under
/// 300ms, decelerate only, and are skipped entirely when the OS asks for
/// reduced motion.
class _RevealMotion extends StatelessWidget {
  const _RevealMotion({
    required this.state,
    required this.reduceMotion,
    required this.child,
  });

  final McqOptionState state;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion ||
        (state != McqOptionState.wrongReveal &&
            state != McqOptionState.correctReveal)) {
      return child;
    }
    final isWrong = state == McqOptionState.wrongReveal;

    return TweenAnimationBuilder<double>(
      key: ValueKey(state.name),
      tween: Tween(begin: 0, end: 1),
      duration: isWrong ? AppMotion.standard : AppMotion.snappy,
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final dx = isWrong ? math.sin(t * math.pi * 3) * 6 * (1 - t) : 0.0;
        final scale = isWrong ? 1.0 : 0.98 + 0.02 * t;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}
