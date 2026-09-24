import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Ambient banner displaying live pulse information about scholars discussing syllabus topics.
class CommunityPulseBanner extends StatelessWidget {
  const CommunityPulseBanner({
    required this.selectedTrack,
    required this.onDismiss,
    super.key,
  });

  final String selectedTrack;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary
              : colors.surfaceSecondary.withAlpha(160),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 35 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 20 : 5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ambient Glowing Orb
            Positioned(
              right: -10,
              bottom: -10,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withAlpha(isDark ? 25 : 15),
                ),
              ),
            ),

            // Banner Content
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Insights Pulse Icon with live indicator dot
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withAlpha(
                            isDark ? 40 : 25,
                          ),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.success,
                            border: Border.all(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Text Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'COMMUNITY PULSE',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '1,420 scholars ',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 12.5,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'discussing ${selectedTrack == 'All' ? 'community' : selectedTrack} syllabus shifts',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dismiss Button
                  ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      onDismiss();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.textSecondary.withAlpha(
                          isDark ? 40 : 25,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
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
