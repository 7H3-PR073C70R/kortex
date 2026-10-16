import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Action buttons displayed inside `FileDropZoneWidget` to browse files,
/// launch camera scanner, or open LMS import modal.
class DropZoneActionButtons extends StatelessWidget {
  const DropZoneActionButtons({
    required this.onPickFile,
    this.onCameraScanTap,
    this.onLmsImportTap,
    super.key,
  });

  final VoidCallback onPickFile;
  final VoidCallback? onCameraScanTap;
  final VoidCallback? onLmsImportTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        // Browse Files Button
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return AnimatedScale(
              scale: isHovered ? 1.04 : 1.0,
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              child: child,
            );
          },
          child: ShrinkableButton(
            onTap: onPickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withAlpha(210),
                  ],
                ),
                borderRadius: AppRadius.radiusCard,
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(
                      isDark ? 50 : 20,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    color: colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.browseFilesButton,
                    style: typography.footnote.bold.copyWith(
                      color: colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Camera Scanner Button (Supported on iOS & Android only)
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android) &&
            onCameraScanTap != null)
          PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return AnimatedScale(
                scale: isHovered ? 1.04 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: child,
              );
            },
            child: ShrinkableButton(
              onTap: onCameraScanTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceTertiary
                      : colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusCard,
                  border: Border.all(
                    color: colors.primary.withAlpha(
                      isDark ? 90 : 60,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.cameraCaptureButton,
                      style: typography.footnote.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // LMS Import Button
        if (onLmsImportTap != null)
          PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return AnimatedScale(
                scale: isHovered ? 1.04 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: child,
              );
            },
            child: ShrinkableButton(
              onTap: onLmsImportTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceTertiary
                      : colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusCard,
                  border: Border.all(
                    color: colors.primary.withAlpha(
                      isDark ? 90 : 60,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Import LMS',
                      style: typography.footnote.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
