import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Diagram preview card placed under the card question header,
/// supporting visual diagram enlargement, swapping, and removal.
class ExtractedDiagramPreviewSection extends StatelessWidget {
  const ExtractedDiagramPreviewSection({
    required this.imageUrl,
    required this.availableImageUrls,
    required this.onAttachDiagramTap,
    required this.onSwapDiagramTap,
    required this.onRemoveDiagramTap,
    super.key,
  });

  final String? imageUrl;
  final List<String> availableImageUrls;
  final VoidCallback onAttachDiagramTap;
  final VoidCallback onSwapDiagramTap;
  final VoidCallback onRemoveDiagramTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    if (hasImage) {
      return Container(
        decoration: BoxDecoration(
          color: isDark
              ? colors.backgroundSecondary.withAlpha(120)
              : colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 60 : 35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diagram Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_motion_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.extractedVisualDiagramLabel,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (availableImageUrls.length > 1)
                    PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedContainer(
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isHovered
                                ? colors.primary.withAlpha(25)
                                : context.colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            tooltip: 'Swap diagram',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            onPressed: onSwapDiagramTap,
                          ),
                        );
                      },
                    ),
                  PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? colors.error.withAlpha(25)
                              : context.colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppRadius.badge,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colors.error.withAlpha(200),
                          ),
                          tooltip: 'Remove diagram',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: onRemoveDiagramTap,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Visual Diagram Image with Tap-to-Enlarge
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card - 4),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 100,
                    maxHeight: 220,
                  ),
                  width: double.infinity,
                  color: colors.black.withAlpha(isDark ? 80 : 25),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Center(
                        child: AppMultimodalImage(
                          imageUrl: imageUrl!,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(
                            AppRadius.badge,
                          ),
                          border: Border.all(
                            color: colors.white.withAlpha(40),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 13,
                              color: colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.tapToEnlargeDiagramHint,
                              style: typography.caption.medium.copyWith(
                                color: colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (availableImageUrls.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return ShrinkableButton(
                onTap: onAttachDiagramTap,
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.primary.withAlpha(isDark ? 40 : 30)
                        : colors.primary.withAlpha(isDark ? 25 : 15),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: isHovered
                          ? colors.primary
                          : colors.primary.withAlpha(isDark ? 65 : 40),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Attach Diagram',
                        style: typography.caption.medium.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
