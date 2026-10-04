import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/bionic_text_formatter.dart';
import 'package:kortex/src/core/utils/latex_ast_cache.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';

class ParsedOptionItem {
  const ParsedOptionItem({
    required this.letter,
    required this.text,
  });

  final String letter;
  final String text;
}

class ParsedCardFaceContent {
  const ParsedCardFaceContent({
    required this.prompt,
    this.options = const [],
  });

  factory ParsedCardFaceContent.parse(String text) {
    if (text.trim().isEmpty) {
      return const ParsedCardFaceContent(prompt: '');
    }

    // 1. Explicit Options Header pattern:
    // e.g. "**Options:**\n• A. hook\n• B. ..." or "Options:\nA. hook\nB. ..."
    final optionsHeaderRegex = RegExp(
      r'(?:\*\*Options:\*\*|Options:)\s*\n([\s\S]+)',
      caseSensitive: false,
    );

    final headerMatch = optionsHeaderRegex.firstMatch(text);
    if (headerMatch != null) {
      final promptText = text.substring(0, headerMatch.start).trim();
      final rawOptions = headerMatch.group(1) ?? '';
      final parsedList = _parseOptionLines(rawOptions);
      if (parsedList.isNotEmpty) {
        return ParsedCardFaceContent(
          prompt: promptText.isNotEmpty ? promptText : text.trim(),
          options: parsedList,
        );
      }
    }

    // 2. Sequential Option Lines pattern without explicit header:
    // e.g. lines starting with "• A.", "A.", "A)", "(A)"
    final lines = text.split('\n');
    final optionIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (_isOptionLine(line)) {
        optionIndices.add(i);
      }
    }

    // If at least 2 option lines are detected sequentially at the end of the text
    if (optionIndices.length >= 2) {
      final firstOptIdx = optionIndices.first;
      // Ensure the options are concentrated towards the end
      var isContiguous = true;
      for (var j = 0; j < optionIndices.length - 1; j++) {
        // Allow at most 1 blank line between options
        if (optionIndices[j + 1] - optionIndices[j] > 2) {
          isContiguous = false;
          break;
        }
      }

      if (isContiguous) {
        final promptText = lines.sublist(0, firstOptIdx).join('\n').trim();
        final rawOptions = lines.sublist(firstOptIdx).join('\n');
        final parsedList = _parseOptionLines(rawOptions);
        if (parsedList.isNotEmpty) {
          return ParsedCardFaceContent(
            prompt: promptText.isNotEmpty ? promptText : text.trim(),
            options: parsedList,
          );
        }
      }
    }

    return ParsedCardFaceContent(prompt: text.trim());
  }

  static bool _isOptionLine(String line) {
    if (line.isEmpty) return false;
    final regex = RegExp(
      r'^(?:[•\*\-]\s*)?(?:[A-Ea-e][\.\)]|\([A-Ea-e]\))\s+',
    );
    return regex.hasMatch(line);
  }

  static List<ParsedOptionItem> _parseOptionLines(String rawOptions) {
    final list = <ParsedOptionItem>[];
    const defaultLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

    for (final rawLine in rawOptions.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final cleaned = trimmed
          .replaceAll('✅', '')
          .replaceAll('•', '')
          .replaceAll('*', '')
          .replaceAll('-', '')
          .trim();

      // Normalize duplicate prefixes like "A. A. Option Text" or "(A) Option Text"
      final match = RegExp(
        r'^(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*(?:(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*)?(.*)',
      ).firstMatch(cleaned);

      if (match != null) {
        final letter = (match.group(1) ?? match.group(2) ?? '').toUpperCase();
        final content = match.group(5)?.trim() ?? '';
        list.add(ParsedOptionItem(letter: letter, text: content));
      } else {
        // Fallback for lines without explicit letters
        final fallbackLetter = list.length < defaultLetters.length
            ? defaultLetters[list.length]
            : '${list.length + 1}';
        list.add(ParsedOptionItem(letter: fallbackLetter, text: cleaned));
      }
    }

    return list;
  }

  final String prompt;
  final List<ParsedOptionItem> options;
}

class LatexCardContentViewer extends StatelessWidget {
  const LatexCardContentViewer({
    required this.text,
    this.latexFormula,
    this.imageUrl,
    this.isBackFace = false,
    this.enableBionicReading = false,
    super.key,
  });

  final String text;
  final String? latexFormula;
  final String? imageUrl;
  final bool isBackFace;
  final bool enableBionicReading;

  Widget _buildImage(
    String url, {
    required BoxFit fit,
    double? width,
    double? height,
    Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return AppMultimodalImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      enableZoomOnTap: false,
    );
  }

  void _showExpandedImage(BuildContext context, String url) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: context.colors.black.withAlpha(220),
        builder: (dialogCtx) {
          final colors = dialogCtx.colors;
          final l10n = dialogCtx.l10n;

          return Dialog(
            backgroundColor: colors.transparent,
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
                      child: _buildImage(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 250,
                            alignment: Alignment.center,
                            child: const AppLogoLoader(size: 48),
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
                    icon: Icon(Icons.close_rounded, color: colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.black.withAlpha(160),
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

  Widget _buildLatexFormulaBox(
    BuildContext context,
    String formula,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final cleanFormula = LatexAstCache.instance.getOrCleanFormula(formula);
    final fallbackReadable = LatexAstCache.instance
        .formatLatexHumanReadableFallback(formula);

    return Container(
      width: double.infinity,
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
            color: colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Math.tex(
            cleanFormula,
            textStyle: context.typography.body.regular.copyWith(
              fontSize: 18,
              color: colors.textPrimary,
            ),
            onErrorFallback: (err) => Text(
              fallbackReadable.isNotEmpty ? fallbackReadable : cleanFormula,
              style: typography.callout.medium.copyWith(
                color: colors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(
    BuildContext context,
    String url,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final l10n = context.l10n;

    return Semantics(
      label: l10n.tapToEnlargeDiagramHint,
      button: true,
      child: GestureDetector(
        onTap: () => _showExpandedImage(context, url),
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
                  color: colors.black.withAlpha(isDark ? 30 : 10),
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
                  _buildImage(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 120,
                        color: colors.surfaceSecondary,
                        child: const Center(
                          child: AppLogoLoader(size: 32),
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
                              l10n.attachedDiagramLabel,
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
                      color: colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.zoom_in_rounded,
                          size: 14,
                          color: colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.tapToEnlargeDiagramHint,
                          style: typography.caption.bold.copyWith(
                            fontSize: 10.5,
                            color: colors.white,
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
    );
  }

  Widget _buildOptionsSection(
    BuildContext context,
    List<ParsedOptionItem> options,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 12,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'OPTIONS',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...options.map((opt) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary.withAlpha(130)
                  : colors.surfaceSecondary.withAlpha(160),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 80 : 110),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 100 : 70),
                    ),
                  ),
                  child: Text(
                    opt.letter,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LatexRichViewer(
                    text: enableBionicReading
                        ? BionicTextFormatter.format(opt.text)
                        : opt.text,
                    style: typography.callout.regular.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final baseStyle = isBackFace
        ? typography.callout.medium
        : enableBionicReading
        ? typography.title3.regular
        : typography.title3.bold;

    final parsed = isBackFace
        ? ParsedCardFaceContent(prompt: text)
        : ParsedCardFaceContent.parse(text);

    final displayPrompt = enableBionicReading
        ? BionicTextFormatter.format(parsed.prompt)
        : parsed.prompt;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Primary Prompt Text with LaTeX support
        LatexRichViewer(
          key: ValueKey(displayPrompt),
          text: displayPrompt,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: colors.textPrimary,
            fontSize: isBackFace ? 16 : 18.5,
            height: 1.35,
          ),
        ),

        // 2. LaTeX Formula Box (Placed before options)
        if (latexFormula != null && latexFormula!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildLatexFormulaBox(
            context,
            latexFormula!,
            colors,
            typography,
            isDark,
          ),
        ],

        // 3. Multimodal Diagram / Illustration View (Placed before options)
        if (imageUrl != null && imageUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildImageWidget(
            context,
            imageUrl!,
            colors,
            typography,
            isDark,
          ),
        ],

        // 4. Distinct Multiple-Choice Options UI (Rendered below prompt, formula, and image)
        if (!isBackFace && parsed.options.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildOptionsSection(
            context,
            parsed.options,
            colors,
            typography,
            isDark,
          ),
        ],
      ],
    );
  }
}
