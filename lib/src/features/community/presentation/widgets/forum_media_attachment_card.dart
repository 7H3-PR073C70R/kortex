import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Extracts a clean display filename from a URL or media path.
/// Converts auto-generated image_picker or UUID strings into clean human-readable names.
String extractAttachmentFileName(
  String url, {
  int? index,
  String fallback = 'Attachment.png',
}) {
  try {
    final clean = url.trim();
    if (clean.isEmpty) return fallback;
    final uri = Uri.parse(clean);
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final rawLast = segments.last.split('?').first.split('#').first;
      if (rawLast.trim().isNotEmpty) {
        final ext = rawLast.contains('.')
            ? '.${rawLast.split('.').last.toLowerCase()}'
            : '.png';
        final baseName = rawLast.contains('.')
            ? rawLast.substring(0, rawLast.lastIndexOf('.'))
            : rawLast;

        // Check if the baseName is an auto-generated temporary or UUID string:
        final lower = baseName.toLowerCase();
        final isGeneratedOrWeird =
            lower.startsWith('image_picker') ||
            lower.startsWith('scaled_') ||
            lower.startsWith('camera_') ||
            lower.startsWith('temp_') ||
            lower.startsWith('file_picker') ||
            lower.startsWith('picker_') ||
            lower.startsWith('img_') && lower.length > 20 ||
            RegExp(r'^[0-9a-fA-F\-]{16,}$').hasMatch(baseName) ||
            RegExp(
              '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}',
            ).hasMatch(baseName);

        if (isGeneratedOrWeird) {
          final isImage =
              ext == '.jpg' ||
              ext == '.jpeg' ||
              ext == '.png' ||
              ext == '.webp' ||
              ext == '.heic';
          final prefix = isImage ? 'Image_Attachment' : 'Attachment';
          final idx = (index != null && index > 0) ? '_${index + 1}' : '';
          return '$prefix$idx$ext';
        }

        return rawLast;
      }
    }
  } on Object catch (_) {}
  return fallback;
}

/// A compact attachment card for forum replies matching the design specification:
/// Thumbnail Preview | FileName.png | Zoom Icon
/// Subtitle: PNG • Image Attachment
class ForumReplyAttachmentCard extends StatelessWidget {
  const ForumReplyAttachmentCard({
    required this.imageUrl,
    this.customFileName,
    this.customSubtitle,
    super.key,
  });

  final String imageUrl;
  final String? customFileName;
  final String? customSubtitle;

  void _showEnlarged(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final colors = context.colors;
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: colors.black.withAlpha(230),
        builder: (ctx) {
          return Dialog(
            backgroundColor: colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  maxScale: 4,
                  child: AppMultimodalImage(
                    imageUrl: imageUrl,
                    enableZoomOnTap: false,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.black.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final fileName = customFileName ?? extractAttachmentFileName(imageUrl);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'PNG';
    final subtitle = customSubtitle ?? '$ext • Image Attachment';

    return ShrinkableButton(
      onTap: () => _showEnlarged(context),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfacePrimary.withAlpha(180)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? colors.surfaceBorder.withAlpha(50)
                : colors.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: AppMultimodalImage(
                  imageUrl: imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  enableZoomOnTap: false,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // File Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Zoom / Inspect Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(120)
                    : colors.primary.withAlpha(20),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hero media preview widget for main forum post headers and forum post cards:
/// - 1 image: Large rounded rectangle with subtle border and optional caption
/// - 2+ images: Side-by-side split grid with `1 / N` badge and `+N more` overlay
class ForumPostMediaPreview extends StatelessWidget {
  const ForumPostMediaPreview({
    required this.mediaUrls,
    this.caption,
    this.heroHeight = 150,
    super.key,
  });

  final List<String> mediaUrls;
  final String? caption;
  final double heroHeight;

  void _showEnlarged(BuildContext context, String url) {
    unawaited(HapticFeedback.lightImpact());
    final colors = context.colors;
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: colors.black.withAlpha(230),
        builder: (ctx) {
          return Dialog(
            backgroundColor: colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  maxScale: 4,
                  child: AppMultimodalImage(
                    imageUrl: url,
                    enableZoomOnTap: false,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.black.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final hasMultiple = mediaUrls.length > 1;
    final firstUrl = mediaUrls.first;
    final secondUrl = hasMultiple ? mediaUrls[1] : '';
    final remainingCount = mediaUrls.length - 2;

    final displayCaption =
        caption ??
        (hasMultiple
            ? '${extractAttachmentFileName(firstUrl)} • ${mediaUrls.length} images'
            : extractAttachmentFileName(firstUrl));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: heroHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorder.withAlpha(50)
                  : colors.surfaceBorder,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: !hasMultiple
              ? ShrinkableButton(
                  onTap: () => _showEnlarged(context, firstUrl),
                  child: SizedBox(
                    width: double.infinity,
                    height: heroHeight,
                    child: AppMultimodalImage(
                      imageUrl: firstUrl,
                      width: double.infinity,
                      height: heroHeight,
                      fit: BoxFit.cover,
                      enableZoomOnTap: false,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Left image tile
                    Expanded(
                      child: ShrinkableButton(
                        onTap: () => _showEnlarged(context, firstUrl),
                        child: SizedBox(
                          height: heroHeight,
                          child: AppMultimodalImage(
                            imageUrl: firstUrl,
                            height: heroHeight,
                            fit: BoxFit.cover,
                            enableZoomOnTap: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Right image tile
                    Expanded(
                      child: ShrinkableButton(
                        onTap: () => _showEnlarged(context, secondUrl),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppMultimodalImage(
                              imageUrl: secondUrl,
                              height: heroHeight,
                              fit: BoxFit.cover,
                              enableZoomOnTap: false,
                            ),
                            // Top right counter badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.black.withAlpha(180),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '1 / ${mediaUrls.length}',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            // Centered overlay if more than 2 images
                            if (remainingCount > 0)
                              Container(
                                color: colors.black.withAlpha(120),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      color: colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+$remainingCount more',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Caption / filename indicator
        if (displayCaption.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayCaption,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasMultiple) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
