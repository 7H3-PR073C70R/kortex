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
        color: const Color(0xFFEF4444),
      ),
      (
        label: l10n.studyRatingHard,
        interval: l10n.studyRatingHardInterval,
        quality: 3,
        color: const Color(0xFFF97316),
      ),
      (
        label: l10n.studyRatingGood,
        interval: l10n.studyRatingGoodInterval,
        quality: 4,
        color: colors.primary,
      ),
      (
        label: l10n.studyRatingEasy,
        interval: l10n.studyRatingEasyInterval,
        quality: 5,
        color: const Color(0xFF10B981),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 4 Frosted Glass Rating Buttons
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
                      unawaited(HapticFeedback.lightImpact());
                      onRate(b.quality);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: b.color.withAlpha(isDark ? 40 : 25),
                            border: Border.all(
                              color: b.color.withAlpha(isDark ? 130 : 90),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: b.color.withAlpha(isDark ? 50 : 20),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                b.label,
                                style: typography.caption.bold.copyWith(
                                  color: b.color,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.interval,
                                style: typography.footnote.medium.copyWith(
                                  color: isDark
                                      ? colors.textSecondary
                                      : colors.textMuted,
                                  fontSize: 11,
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

        const SizedBox(height: 12),

        // Keyboard Shortcuts / Gesture Guidance
        Text(
          l10n.studySessionKeyboardShortcuts,
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
