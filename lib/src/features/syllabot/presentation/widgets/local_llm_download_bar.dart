import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom bar overlay displayed when downloading the on-device local LLM model
/// weights. Replaces the chat input field and keeps the active engine visibly
/// set to Cloud.
class LocalLlmDownloadBar extends StatelessWidget {
  const LocalLlmDownloadBar({
    required this.progress,
    required this.onCancel,
    this.currentEngine = ExecutionEngineType.cloudRemote,
    super.key,
  });

  final double progress;
  final VoidCallback onCancel;
  final ExecutionEngineType currentEngine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final percent = (progress.clamp(0.0, 1.0) * 100).toInt();
    final downloadedMb = (progress.clamp(0.0, 1.0) * 248.0).toStringAsFixed(1);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ClipRRect(
          borderRadius: AppRadius.radiusDialog,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary.withAlpha(225)
                    : colors.surfacePrimary.withAlpha(240),
                borderRadius: AppRadius.radiusDialog,
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 90 : 60),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 40 : 15),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header: Download status & Cancel button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.downloading_rounded,
                              color: colors.primary,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Downloading On-Device Engine',
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Active: ${l10n.engineCloudSupabase}',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: onCancel,
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.snappyCurve,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.error.withAlpha(25)
                                    : colors.surfaceSecondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isHovered
                                      ? colors.error.withAlpha(120)
                                      : colors.surfaceBorder.withAlpha(80),
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isHovered
                                    ? colors.error
                                    : colors.textSecondary,
                                size: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Linear Progress Bar
                  ClipRRect(
                    borderRadius: AppRadius.radiusMicro,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: colors.surfaceSecondary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.syllabotAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. Percentage & MB count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$percent% Completed',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        '$downloadedMb MB / 248.0 MB',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
