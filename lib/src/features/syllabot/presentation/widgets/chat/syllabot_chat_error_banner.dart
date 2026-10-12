import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Actionable error banner with 1-tap retry and optional on-device AI switch.
class SyllabotChatErrorBanner extends StatelessWidget {
  const SyllabotChatErrorBanner({
    required this.state,
    required this.onSwitchToLocalEngine,
    required this.onRetry,
    super.key,
  });

  final SyllabotChatState state;
  final VoidCallback onSwitchToLocalEngine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.status != SyllabotStatus.error ||
        state.errorMessage == null ||
        state.errorMessage!.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final isCloudError = state.engineType == ExecutionEngineType.cloudRemote;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withAlpha(isDark ? 35 : 20),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.error.withAlpha(isDark ? 90 : 70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCloudError
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                color: colors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCloudError
                      ? (state.errorMessage ??
                          'Network error. Connect to network or switch to On-Device AI.')
                      : 'On-Device Engine encountered an issue. Tap retry.',
                  style: typography.caption.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 1-Tap Switch to On-Device AI
              if (!kIsWeb &&
                  state.engineType == ExecutionEngineType.cloudRemote)
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      onTap: onSwitchToLocalEngine,
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? colors.surfaceSecondary.withAlpha(220)
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                          border: Border.all(
                            color: isHovered
                                ? colors.primary.withAlpha(160)
                                : colors.surfaceBorder.withAlpha(120),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '⚡',
                              style: context.typography.body.regular
                                  .copyWith(fontSize: 10),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Use On-Device AI',
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // 1-Tap Retry Button
              if (state.lastPrompt != null)
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      onTap: onRetry,
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? colors.error.withAlpha(220)
                              : colors.error,
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.retryAction,
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
