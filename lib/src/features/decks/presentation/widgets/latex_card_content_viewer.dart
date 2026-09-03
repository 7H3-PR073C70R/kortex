import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
        barrierColor: Colors.black.withAlpha(220),
        builder: (dialogCtx) {
          final colors = dialogCtx.colors;
          final l10n = dialogCtx.l10n;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 600,
                      maxHeight: 500,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withAlpha(80),
                      ),
                    ),
                    child: InteractiveViewer(
                      maxScale: 4,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 250,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 200,
                          padding: const EdgeInsets.all(24),
                          child: Center(
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
                                  l10n.attachedDiagramLabel,
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
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final baseStyle = isBackFace
        ? typography.callout.medium
        : typography.title3.bold;

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
            label: l10n.tapToEnlargeDiagramHint,
            button: true,
            child: GestureDetector(
              onTap: () => _showExpandedImage(context, imageUrl!),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary.withAlpha(140)
                        : colors.surfaceSecondary.withAlpha(180),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 80 : 40),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 25 : 8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Image.network(
                          imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 120,
                              color: colors.surfaceSecondary,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
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
                                        l10n.attachedDiagramLabel,
                                        style: typography.footnote.regular
                                            .copyWith(
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.zoom_in_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.tapToEnlargeDiagramHint,
                                style: const TextStyle(
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
