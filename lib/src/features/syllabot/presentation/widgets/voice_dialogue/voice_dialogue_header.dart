import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Adaptive Top Navigation Header for the Voice Dialogue Modal.
class VoiceDialogueHeader extends StatelessWidget {
  const VoiceDialogueHeader({
    required this.engineType,
    required this.initialMode,
    required this.selectedGender,
    required this.isDesktop,
    required this.onToggleGender,
    required this.onCloseModal,
    super.key,
  });

  final ExecutionEngineType engineType;
  final SocraticMode initialMode;
  final VoiceGender selectedGender;
  final bool isDesktop;
  final VoidCallback onToggleGender;
  final VoidCallback onCloseModal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final isLocalEngine = engineType == ExecutionEngineType.localOnDevice;
    final engineColor = isLocalEngine ? colors.success : colors.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Group: Mode Chip & Branding (Flexible to prevent horizontal overflow)
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: engineColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: engineColor.withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLocalEngine
                      ? Icons.memory_rounded
                      : Icons.graphic_eq_rounded,
                  color: engineColor,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isLocalEngine ? 'On-Device AI' : 'Syllabot Voice',
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.bold.copyWith(
                      color: engineColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: engineColor.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      initialMode.label,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Right Group: Voice Persona Controls & Close
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice Gender Selector Pill
            PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return ShrinkableButton(
                  onTap: onToggleGender,
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.snappyCurve,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isHovered
                            ? colors.primary.withValues(alpha: 0.4)
                            : colors.surfaceBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectedGender == VoiceGender.female
                              ? Icons.face_3_rounded
                              : Icons.face_6_rounded,
                          color: colors.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedGender == VoiceGender.female
                              ? l10n.voiceGenderFemale
                              : l10n.voiceGenderMale,
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: colors.textSecondary,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 4),

            // Desktop Esc Key Hint
            if (isDesktop) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary.withValues(alpha: 0.8),
                  borderRadius: AppRadius.radiusMicro,
                  border: Border.all(
                    color: colors.surfaceBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Esc',
                  style: typography.caption.regular.copyWith(
                    color: colors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Close Modal Button
            PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return IconButton(
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: 'Close Voice Dialogue',
                  icon: Icon(
                    Icons.close_rounded,
                    color: isHovered ? colors.primary : colors.textPrimary,
                  ),
                  onPressed: onCloseModal,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
