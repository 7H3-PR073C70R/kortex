import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_socratic_mode_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Row of configuration selector pills at the base of the Syllabot input container:
/// 1. Socratic reasoning mode selector pill.
/// 2. Execution engine switcher pill (Cloud AI vs. On-Device AI).
class SyllabotInputModePills extends StatelessWidget {
  const SyllabotInputModePills({
    required this.socraticMode,
    required this.engineType,
    required this.onOpenModeSheet,
    required this.onEngineChanged,
    super.key,
  });

  final SocraticMode socraticMode;
  final ExecutionEngineType engineType;
  final VoidCallback onOpenModeSheet;
  final ValueChanged<ExecutionEngineType> onEngineChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Socratic Mode Selector Pill
        Flexible(
          child: PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              final modeDetails =
                  SocraticModeDetailsHelper.getModeDetails(socraticMode, l10n);
              final shortLabel =
                  SocraticModeDetailsHelper.getModeShortLabel(socraticMode, l10n);

              return ShrinkableButton(
                onTap: onOpenModeSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.primary.withAlpha(20)
                        : colors.surfaceSecondary,
                    borderRadius: AppRadius.radiusBadge,
                    border: Border.all(
                      color: isHovered
                          ? colors.primary.withAlpha(120)
                          : colors.surfaceBorder.withAlpha(90),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        modeDetails.$1,
                        style: context.typography.body.regular.copyWith(
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          shortLabel,
                          style: typography.caption.bold.copyWith(
                            color: isHovered
                                ? colors.primary
                                : colors.textPrimary,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isHovered
                            ? colors.primary
                            : colors.textSecondary,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // 2. Interactive AI Engine Pill (Cloud AI / On-Device AI)
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final isCloud = engineType == ExecutionEngineType.cloudRemote;

            return ShrinkableButton(
              onTap: () {
                if (kIsWeb) {
                  context.showSnackBar(
                    message:
                        'On-Device AI is available on Kortex Mobile apps (Android & iOS).',
                  );
                  return;
                }
                unawaited(HapticFeedback.lightImpact());
                final nextEngine = isCloud
                    ? ExecutionEngineType.localOnDevice
                    : ExecutionEngineType.cloudRemote;
                onEngineChanged(nextEngine);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isHovered
                      ? colors.primary.withAlpha(20)
                      : colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: isHovered
                        ? colors.primary.withAlpha(120)
                        : colors.surfaceBorder.withAlpha(90),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCloud ? colors.success : colors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCloud
                          ? l10n.engineCloudSupabase
                          : l10n.engineLocalOnDevice,
                      style: typography.caption.bold.copyWith(
                        color: isHovered
                            ? colors.primary
                            : colors.textPrimary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
