import 'dart:async';

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
///
/// Shows a predicted next interval per rating (when [intervalPreviews] is
/// provided) so the learner can feel the cost of each choice — the same
/// "what will this do to my future queue" legibility that makes Anki's
/// rating bar effective.
class FsrsRatingActionBar extends StatelessWidget {
  const FsrsRatingActionBar({
    required this.onRateRating,
    this.intervalPreviews = const {},
    super.key,
  });

  final void Function(FsrsRating rating) onRateRating;

  /// Predicted days-to-next-review per rating for the CURRENT card.
  /// Empty while unknown — the buttons then render without a preview line.
  final Map<FsrsRating, int> intervalPreviews;

  /// Formats a predicted interval compactly under the "days" idiom the
  /// existing interval labels establish ("< 10m", "1d", "6d", "12d").
  static String formatPreview(int days) {
    if (days <= 0) return '<10m';
    if (days == 1) return '1d';
    if (days < 30) return '${days}d';
    if (days < 365) return '${(days / 30).round()}mo';
    return '${(days / 365).floor()}y';
  }

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
        color: colors.recallAgain,
        icon: Icons.replay_rounded,
        shortcut: '1',
      ),
      (
        label: l10n.studyRatingHard,
        rating: FsrsRating.hard,
        color: colors.recallHard,
        icon: Icons.bolt_rounded,
        shortcut: '2',
      ),
      (
        label: l10n.studyRatingGood,
        rating: FsrsRating.good,
        color: colors.recallGood,
        icon: Icons.thumb_up_rounded,
        shortcut: '3',
      ),
      (
        label: l10n.studyRatingEasy,
        rating: FsrsRating.easy,
        color: colors.recallEasy,
        icon: Icons.rocket_launch_rounded,
        shortcut: '4',
      ),
    ];

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 780 : 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: buttons.map((b) {
                final previewDays = intervalPreviews[b.rating];
                final preview = previewDays == null
                    ? null
                    : formatPreview(previewDays);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 8 : 4,
                    ),
                    child: Semantics(
                      button: true,
                      label: preview == null
                          ? b.label
                          : l10n.studyRatingSemantics(b.label, preview),
                      child: PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            key: ValueKey('fsrs_rating_${b.rating.name}'),
                            onTap: () {
                              switch (b.rating) {
                                case FsrsRating.again:
                                  unawaited(HapticFeedback.heavyImpact());
                                case FsrsRating.hard:
                                  unawaited(HapticFeedback.mediumImpact());
                                case FsrsRating.good:
                                  unawaited(HapticFeedback.lightImpact());
                                case FsrsRating.easy:
                                  unawaited(HapticFeedback.selectionClick());
                              }
                              onRateRating(b.rating);
                            },
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.snappyCurve,
                              padding: EdgeInsets.symmetric(
                                vertical: isDesktop ? 16 : 12,
                                horizontal: isDesktop ? 12 : 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                                color: isHovered
                                    ? b.color.withAlpha(isDark ? 65 : 45)
                                    : (isDark
                                          ? b.color.withAlpha(38)
                                          : b.color.withAlpha(24)),
                                border: Border.all(
                                  color: b.color.withAlpha(
                                    isHovered ? 200 : (isDark ? 120 : 85),
                                  ),
                                  width: isHovered ? 1.6 : 1.2,
                                ),
                                boxShadow: isHovered
                                    ? [
                                        BoxShadow(
                                          color: b.color.withAlpha(
                                            isDark ? 70 : 35,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icon indicator
                                  Icon(
                                    b.icon,
                                    color: b.color,
                                    size: isDesktop ? 22 : 20,
                                  ),
                                  const SizedBox(height: 6),

                                  // Button Label
                                  Text(
                                    b.label,
                                    style: typography.body.bold.copyWith(
                                      color: isDark
                                          ? colors.white
                                          : colors.textPrimary,
                                      fontSize: isDesktop ? 15 : 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // High-contrast Predicted Next Interval Pill
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isDesktop ? 8 : 6,
                                      vertical: isDesktop ? 3 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: b.color.withAlpha(
                                        isDark ? 60 : 40,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      preview ??
                                          _fallbackPreview(context, b.rating),
                                      style: typography.caption.bold.copyWith(
                                        color: isDark ? colors.white : b.color,
                                        fontSize: isDesktop ? 12 : 11.5,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Keyboard Key Hint
                                  Text(
                                    l10n.studyRatingKeyShortcut(b.shortcut),
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textMuted,
                                      fontSize: isDesktop ? 11 : 10,
                                    ),
                                  ),
                                ],
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

  String _fallbackPreview(BuildContext context, FsrsRating rating) {
    final l10n = context.l10n;
    return switch (rating) {
      FsrsRating.again => l10n.studyRatingAgainInterval,
      FsrsRating.hard => l10n.studyRatingHardInterval,
      FsrsRating.good => l10n.studyRatingGoodInterval,
      FsrsRating.easy => l10n.studyRatingEasyInterval,
    };
  }
}
