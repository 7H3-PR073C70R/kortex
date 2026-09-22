import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class EngineStatusIndicator extends StatelessWidget {
  const EngineStatusIndicator({
    required this.engineType,
    required this.onToggleEngine,
    super.key,
  });

  final ExecutionEngineType engineType;
  final ValueChanged<ExecutionEngineType> onToggleEngine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isCloud = engineType == ExecutionEngineType.cloudRemote;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            final nextEngine = isCloud
                ? ExecutionEngineType.localOnDevice
                : ExecutionEngineType.cloudRemote;
            onToggleEngine(nextEngine);

            context.showSnackBar(
              message: l10n.engineSwitched(
                nextEngine == ExecutionEngineType.cloudRemote
                    ? l10n.engineCloudSupabase
                    : l10n.engineLocalOnDevice,
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCloud
                  ? (isHovered
                        ? colors.primary.withAlpha(isDark ? 70 : 45)
                        : colors.primary.withAlpha(isDark ? 40 : 25))
                  : (isHovered
                        ? colors.warning.withAlpha(isDark ? 70 : 45)
                        : colors.warning.withAlpha(isDark ? 40 : 25)),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: isCloud
                    ? (isHovered
                          ? colors.primary.withAlpha(isDark ? 160 : 120)
                          : colors.primary.withAlpha(isDark ? 100 : 80))
                    : (isHovered
                          ? colors.warning.withAlpha(isDark ? 160 : 120)
                          : colors.warning.withAlpha(isDark ? 100 : 80)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCloud ? colors.success : colors.warning,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isCloud ? l10n.engineCloudSupabase : l10n.engineLocalOnDevice,
                  style: typography.caption.medium.copyWith(
                    color: isCloud ? colors.textPrimary : colors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 13,
                  color: isHovered ? colors.primary : colors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
