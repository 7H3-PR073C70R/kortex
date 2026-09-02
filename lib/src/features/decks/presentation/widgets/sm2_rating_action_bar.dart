import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class Sm2RatingActionBar extends StatelessWidget {
  const Sm2RatingActionBar({
    required this.onRate,
    super.key,
  });

  final void Function(int quality) onRate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final buttons = [
      (
        label: l10n.studyRatingAgain,
        interval: l10n.studyRatingAgainInterval,
        quality: 0,
        color: colors.recallAgain,
        icon: Icons.replay_rounded,
        shortcut: '1',
      ),
      (
        label: l10n.studyRatingHard,
        interval: l10n.studyRatingHardInterval,
        quality: 3,
        color: colors.recallHard,
        icon: Icons.bolt_rounded,
        shortcut: '2',
      ),
      (
        label: l10n.studyRatingGood,
        interval: l10n.studyRatingGoodInterval,
        quality: 4,
        color: colors.recallGood,
        icon: Icons.thumb_up_rounded,
        shortcut: '3',
      ),
      (
        label: l10n.studyRatingEasy,
        interval: l10n.studyRatingEasyInterval,
        quality: 5,
        color: colors.recallEasy,
        icon: Icons.rocket_launch_rounded,
        shortcut: '4',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 4 Modern Tactile Rating Cards
        Row(
          children: buttons.map((b) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  button: true,
                  label: '${b.label}, review in ${b.interval}',
                  child: ShrinkableButton(
                    key: ValueKey('sm2_rating_${b.quality}'),
                    onTap: () {
                      unawaited(HapticFeedback.mediumImpact());
                      onRate(b.quality);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isDark
                                ? b.color.withAlpha(35)
                                : b.color.withAlpha(20),
                            border: Border.all(
                              color: b.color.withAlpha(isDark ? 110 : 80),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: b.color.withAlpha(isDark ? 40 : 15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Interval Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: b.color.withAlpha(isDark ? 60 : 35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  b.interval,
                                  style: typography.caption.bold.copyWith(
                                    color: b.color,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Button Label
                              Text(
                                b.label,
                                style: typography.body.bold.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Keyboard Key Hint
                              Text(
                                l10n.studyRatingKeyShortcut(b.shortcut),
                                style: typography.caption.regular.copyWith(
                                  color: colors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 10),

        // 4-Way Gesture Guidance
        Text(
          l10n.studySessionSwipe4WayHint,
          textAlign: TextAlign.center,
          style: typography.footnote.regular.copyWith(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
