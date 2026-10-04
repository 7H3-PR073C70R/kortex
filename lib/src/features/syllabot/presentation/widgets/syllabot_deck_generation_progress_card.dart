import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// A premium visual feedback card displayed in the Syllabot AI chat view
/// while flashcards are being synthesized in the background.
class SyllabotDeckGenerationProgressCard extends StatelessWidget {
  const SyllabotDeckGenerationProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(220)
            : colors.surfacePrimary.withAlpha(240),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.syllabotAccent.withAlpha(isDark ? 80 : 50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.syllabotAccent.withAlpha(isDark ? 25 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Glowing / Pulsing Sparkles Icon
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.syllabotAccent.withAlpha(isDark ? 40 : 25),
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: colors.syllabotAccent.withAlpha(isDark ? 70 : 45),
                        ),
                      ),

                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.syllabotAccent,
                        size: 20,
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scaleXY(
                            begin: 0.92,
                            end: 1.08,
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          )
                          .shimmer(
                            duration: 1800.ms,
                            color: colors.syllabotAccent.withAlpha(120),
                          ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.generatingDeckProgress,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.syllabotAccent.withAlpha(isDark ? 35 : 20),
                                  borderRadius: AppRadius.radiusMicro,
                                  border: Border.all(
                                    color: colors.syllabotAccent.withAlpha(isDark ? 60 : 40),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'AI SYNTHESIS',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.syllabotAccent,
                                    fontSize: 9.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Extracting key formulas, terms, and concept rules from your discussion...',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Indeterminate glowing Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: colors.syllabotAccent.withAlpha(isDark ? 35 : 20),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.syllabotAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, curve: AppMotion.easeOutCubic)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 250.ms,
          curve: AppMotion.easeOutCubic,
        );
  }
}
