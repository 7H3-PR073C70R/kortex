import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

class LatexCardContentViewer extends StatelessWidget {
  const LatexCardContentViewer({
    required this.text,
    this.latexFormula,
    this.imageUrl,
    this.isBackFace = false,
    super.key,
  });

  final String text;
  final String? latexFormula;
  final String? imageUrl;
  final bool isBackFace;

  void _showExpandedImage(BuildContext context, String url) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          final colors = dialogCtx.colors;
          final isDark = dialogCtx.isDarkMode;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  constraints:
                      const BoxConstraints(maxWidth: 800, maxHeight: 600),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131722) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 100 : 60),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 180 : 80),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      maxScale: 4,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.image_not_supported_rounded,
                                  size: 48,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Diagram preview unavailable',
                                  style: dialogCtx.typography.callout.regular
                                      .copyWith(color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(160),
                    ),
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

    final baseStyle =
        isBackFace ? typography.callout.medium : typography.title3.bold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary text
        Text(
          text,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: colors.textPrimary,
            fontSize: isBackFace ? 16 : 18.5,
            height: 1.35,
          ),
        ),

        // Optional Multimodal Diagram / Illustration View
        if (imageUrl != null && imageUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Semantics(
            label: 'Card diagram image. Double-tap to zoom or inspect.',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showExpandedImage(context, imageUrl!),
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 180,
                  maxWidth: 380,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 90 : 50),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 30 : 10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 140,
                            color: colors.surfaceSecondary,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          color: colors.surfaceSecondary.withAlpha(120),
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.insert_photo_outlined,
                                  size: 24,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Visual Diagram Reference',
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tap to expand',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
          ),
        ],

        // Optional LaTeX Formula Box
        if (latexFormula != null && latexFormula!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary.withAlpha(160)
                  : colors.surfaceSecondary.withAlpha(190),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 90 : 60),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 30 : 10),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Math.tex(
                latexFormula!,
                textStyle: TextStyle(
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
                onErrorFallback: (err) => Text(
                  latexFormula!,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
