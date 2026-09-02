import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/l10n/l10n.dart';
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

    final isCloud = engineType == ExecutionEngineType.cloudSupabase;

    return ShrinkableButton(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        final nextEngine = isCloud
            ? ExecutionEngineType.localOnDevice
            : ExecutionEngineType.cloudSupabase;
        onToggleEngine(nextEngine);

        context.showSnackBar(
          message: l10n.engineSwitched(
            nextEngine == ExecutionEngineType.cloudSupabase
                ? l10n.engineCloudSupabase
                : l10n.engineLocalOnDevice,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isCloud
              ? colors.primary.withAlpha(isDark ? 40 : 25)
              : colors.warning.withAlpha(isDark ? 40 : 25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCloud
                ? colors.primary.withAlpha(isDark ? 100 : 80)
                : colors.warning.withAlpha(isDark ? 100 : 80),
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
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
