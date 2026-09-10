import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';

/// Resilient multimodal image widget that reliably displays images from any source:
/// - Full network URLs (HTTP / HTTPS)
/// - Relative Supabase storage asset paths (automatically resolved to public URL)
/// - Base64 data URIs (`data:image/...;base64,...`)
/// - Local filesystem paths (`file://...` or `/path/...`)
/// - Bundled application assets (`assets/...`)
///
/// Also provides tap-to-enlarge interactive zoom inspection.
class AppMultimodalImage extends StatelessWidget {
  const AppMultimodalImage({
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.borderRadius,
    this.enableZoomOnTap = true,
    this.semanticLabel,
    super.key,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool enableZoomOnTap;
  final String? semanticLabel;

  String get _resolvedUrl {
    final clean = imageUrl.trim();
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('data:image') ||
        clean.startsWith('assets/') ||
        clean.startsWith('file://') ||
        clean.startsWith('/')) {
      return clean;
    }
    // Relative Supabase card-assets bucket path
    return AppApiEndpoint.getCardAssetPublicUrl(clean);
  }

  void _showEnlargedDialog(BuildContext context) {
    if (!enableZoomOnTap) return;
    final colors = context.colors;

    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: colors.black.withAlpha(230),
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
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
                      child: Icon(Icons.close_rounded, color: colors.white, size: 20),
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

  Widget _buildContent(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final url = _resolvedUrl;

    Widget errorPlaceholder([String? errorMsg]) => Container(
          width: width,
          height: height ?? 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary.withAlpha(120),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded, color: colors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    errorMsg ?? 'Image unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    Widget loadingPlaceholder() => Container(
          width: width,
          height: height ?? 140,
          decoration: BoxDecoration(
            color: colors.surfaceSecondary.withAlpha(80),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          child: const Center(child: AppLogoLoader(size: 28)),
        );

    // 1. Data URI (Base64)
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx >= 0 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => errorPlaceholder('Invalid image data'),
        );
      } on Object catch (_) {
        return errorPlaceholder('Failed to decode image');
      }
    }

    // 2. Bundled Asset
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => errorPlaceholder('Asset missing'),
      );
    }

    // 3. Local File Path
    if (url.startsWith('file://') || url.startsWith('/')) {
      final cleanPath = url.replaceFirst(RegExp('^file://'), '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => errorPlaceholder('File unreadable'),
        );
      }
      // If absolute path doesn't exist locally, check fallback before failing
      return errorPlaceholder('File not found');
    }

    // 4. Network URL (HTTP / HTTPS)
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return loadingPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) => errorPlaceholder('Failed to load image'),
    );
  }

  @override
  Widget build(BuildContext context) {
    var content = _buildContent(context);

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    if (enableZoomOnTap) {
      content = GestureDetector(
        onTap: () => _showEnlargedDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: content,
        ),
      );
    }

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        image: true,
        child: content,
      );
    }

    return content;
  }
}
