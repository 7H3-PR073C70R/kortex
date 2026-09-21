import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Tactile review rating bar powered by the FSRS-6 spaced repetition algorithm.
class FsrsRatingActionBar extends StatelessWidget {
  const FsrsRatingActionBar({
    required this.onRateRating,
    super.key,
  });

  final void Function(FsrsRating rating) onRateRating;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final buttons = [
      (
        label: l10n.studyRatingAgain,
        rating: FsrsRating.again,
        quality: 0,
        color: colors.recallAgain,
        icon: Icons.replay_rounded,
        shortcut: '1',
      ),
      (
        label: l10n.studyRatingHard,
        rating: FsrsRating.hard,
        quality: 3,
        color: colors.recallHard,
        icon: Icons.bolt_rounded,
        shortcut: '2',
      ),
      (
        label: l10n.studyRatingGood,
        rating: FsrsRating.good,
        quality: 4,
        color: colors.recallGood,
        icon: Icons.thumb_up_rounded,
        shortcut: '3',
      ),
      (
        label: l10n.studyRatingEasy,
        rating: FsrsRating.easy,
        quality: 5,
        color: colors.recallEasy,
        icon: Icons.rocket_launch_rounded,
        shortcut: '4',
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 4 Modern Tactile Rating Cards with generous breathing room
            Row(
              children: buttons.map((b) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Semantics(
                      button: true,
                      label: b.label,
                      child: PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            key: ValueKey('fsrs_rating_${b.rating.name}'),
                            onTap: () {
                              unawaited(HapticFeedback.mediumImpact());
                              onRateRating(b.rating);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.snappyCurve,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    color: isHovered
                                        ? b.color.withAlpha(isDark ? 65 : 45)
                                        : (isDark
                                              ? b.color.withAlpha(35)
                                              : b.color.withAlpha(22)),
                                    border: Border.all(
                                      color: b.color.withAlpha(
                                        isHovered ? 180 : (isDark ? 110 : 85),
                                      ),
                                      width: isHovered ? 1.5 : 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.black.withAlpha(
                                          isHovered
                                              ? (isDark ? 50 : 20)
                                              : (isDark ? 30 : 8),
                                        ),
                                        blurRadius: isHovered ? 14 : 8,
                                        offset: Offset(0, isHovered ? 4 : 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Icon indicator
                                      Icon(
                                        b.icon,
                                        color: b.color,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 8),

                                      // Button Label
                                      Text(
                                        b.label,
                                        style: typography.body.bold.copyWith(
                                          color: isDark
                                              ? colors.white
                                              : colors.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Keyboard Key Hint
                                      Text(
                                        l10n.studyRatingKeyShortcut(b.shortcut),
                                        style: typography.caption.regular
                                            .copyWith(
                                              color: colors.textMuted,
                                              fontSize: 10,
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
        ),
      ),
    );
  }
}
