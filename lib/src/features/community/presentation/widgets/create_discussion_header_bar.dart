import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top header section displaying track dropdown, author avatar, anonymous toggle, and AI assist banner.
class CreateDiscussionHeaderBar extends StatelessWidget {
  const CreateDiscussionHeaderBar({
    required this.selectedTrack,
    required this.availableTracks,
    required this.onTrackChanged,
    required this.isAnonymous,
    required this.onToggleAnonymous,
    required this.userDisplayName,
    required this.isAiBannerVisible,
    required this.onDismissAiBanner,
    super.key,
  });

  final String selectedTrack;
  final List<String> availableTracks;
  final ValueChanged<String> onTrackChanged;
  final bool isAnonymous;
  final VoidCallback onToggleAnonymous;
  final String userDisplayName;
  final bool isAiBannerVisible;
  final VoidCallback onDismissAiBanner;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final userHandle = userDisplayName.toLowerCase().replaceAll(' ', '_');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Channel / Track Dropdown & Public Discourse Pill
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTrack,
                    isDense: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 13,
                    ),
                    dropdownColor: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    items: availableTracks
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text('c/$t'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) onTrackChanged(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary
                      : colors.surfaceSecondary.withAlpha(140),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 13,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Public Discourse',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Author Info Row with Anonymous Switch
        Row(
          children: [
            AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppMotion.easeOutCubic,
              switchOutCurve: AppMotion.easeOutCubic,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: isAnonymous
                  ? AppAvatar(
                      key: const ValueKey('anon_avatar'),
                      customDimension: 36,
                      fallbackIcon: Icon(
                        Icons.masks_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      backgroundColor: isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceTertiary,
                      showBadge: true,
                      badgeColor: colors.textSecondary,
                    )
                  : AppAvatar(
                      key: const ValueKey('public_avatar'),
                      customDimension: 36,
                      name: userDisplayName,
                      showBadge: true,
                      badgeColor: colors.success,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.standard,
                switchInCurve: AppMotion.easeOutCubic,
                child: Column(
                  key: ValueKey(isAnonymous),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: isAnonymous
                            ? [
                                TextSpan(
                                  text: 'Anonymous Scholar ',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                TextSpan(
                                  text: '@incognito',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ]
                            : [
                                TextSpan(
                                  text: '$userDisplayName ',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                TextSpan(
                                  text: '@$userHandle',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAnonymous
                          ? 'Incognito • Identity hidden'
                          : 'Author & Peer Scholar',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Quick Anonymous Mode Toggle
            ShrinkableButton(
              onTap: onToggleAnonymous,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isAnonymous
                      ? colors.primary.withAlpha(isDark ? 40 : 25)
                      : (isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceSecondary.withAlpha(140)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isAnonymous
                        ? colors.primary.withAlpha(80)
                        : colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAnonymous
                          ? Icons.masks_rounded
                          : Icons.visibility_outlined,
                      size: 13,
                      color: isAnonymous ? colors.primary : colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAnonymous ? 'Anonymous' : 'Public',
                      style: typography.caption.bold.copyWith(
                        color: isAnonymous ? colors.primary : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Educational AI Assist Banner
        if (isAiBannerVisible) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Educational AI Assist',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Drafting a problem? Use rich formatting, LaTeX formulas, voice notes, and images to get answers faster.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  onPressed: onDismissAiBanner,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
