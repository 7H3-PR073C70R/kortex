import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Modal bottom sheet allowing users to pick an extracted diagram or enter a custom image URL.
Future<void> showDiagramPickerModalSheet(
  BuildContext context, {
  required List<String> availableImageUrls,
  required String? selectedImageUrl,
  required ValueChanged<String> onImageSelected,
}) async {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  await AppAdaptiveSheet.showModal<void>(
    context: context,
    maxWidth: 640,
    builder: (ctx) {
      final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
      final customUrlController = TextEditingController();

      return Container(
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: isDesktop
              ? BorderRadius.circular(AppRadius.dialog)
              : const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.dialog),
                ),
          boxShadow: isDesktop
              ? [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 80 : 30),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Attach Diagram to Card',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        PlatformHoverBuilder(
                          builder: (context, isHovered, child) {
                            return AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.surfaceSecondary
                                    : context.colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: isHovered
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (availableImageUrls.isNotEmpty) ...[
                      Text(
                        'Extracted from document (${availableImageUrls.length} available):',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: availableImageUrls.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final imgUrl = availableImageUrls[i];
                            final isSelected = selectedImageUrl == imgUrl;

                            return PlatformHoverBuilder(
                              builder: (context, isHovered, child) {
                                return AnimatedScale(
                                  scale: isHovered ? 1.02 : 1.0,
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.easeOutCubic,
                                  child: GestureDetector(
                                    onTap: () {
                                      onImageSelected(imgUrl);
                                      Navigator.of(ctx).pop();
                                    },
                                    child: AnimatedContainer(
                                      duration: AppMotion.snappy,
                                      curve: AppMotion.easeOutCubic,
                                      width: 170,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? colors.surfaceSecondary
                                            : colors.surfacePrimary,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? colors.primary
                                              : (isHovered
                                                  ? colors.primary
                                                      .withAlpha(120)
                                                  : colors.surfaceBorder),
                                          width: isSelected ? 2.5 : 1.2,
                                        ),
                                        boxShadow: isHovered
                                            ? [
                                                BoxShadow(
                                                  color: colors.black
                                                      .withAlpha(
                                                        isDark ? 40 : 15,
                                                      ),
                                                  blurRadius: 10,
                                                  offset: const Offset(
                                                    0,
                                                    4,
                                                  ),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.card - 2,
                                                  ),
                                              child: AppMultimodalImage(
                                                imageUrl: imgUrl,
                                                enableZoomOnTap: false,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(
                                                      4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.check_rounded,
                                                  size: 14,
                                                  color: colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Custom Image URL option
                    Text(
                      'Or paste image / diagram URL:',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customUrlController,
                            decoration: InputDecoration(
                              hintText: 'https://... or storage path',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            style: typography.body.regular.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PlatformHoverBuilder(
                          builder: (context, isHovered, child) {
                            return AnimatedScale(
                              scale: isHovered ? 1.02 : 1.0,
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              child: ElevatedButton(
                                onPressed: () {
                                  final text = customUrlController.text
                                      .trim();
                                  if (text.isNotEmpty) {
                                    onImageSelected(text);
                                    Navigator.of(ctx).pop();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Apply',
                                  style: typography.body.bold.copyWith(
                                    color: colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
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
    },
  );
}
