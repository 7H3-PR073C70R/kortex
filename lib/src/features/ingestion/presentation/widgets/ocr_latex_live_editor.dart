import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class OcrLatexLiveEditor extends HookWidget {
  const OcrLatexLiveEditor({
    required this.snippet,
    required this.onChanged,
    this.availableImageUrls = const [],
    super.key,
  });

  final OcrExtractionEntity snippet;
  final ValueChanged<OcrExtractionEntity> onChanged;
  final List<String> availableImageUrls;

  void _showDiagramPicker(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
        builder: (ctx) {
          final customUrlController = TextEditingController();

          return SafeArea(
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
                                      : Colors.transparent,
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
                              final isSelected = snippet.imageUrl == imgUrl;

                              return PlatformHoverBuilder(
                                builder: (context, isHovered, child) {
                                  return AnimatedScale(
                                    scale: isHovered ? 1.02 : 1.0,
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    child: GestureDetector(
                                      onTap: () {
                                        onChanged(
                                          snippet.copyWith(imageUrl: imgUrl),
                                        );
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
                                                    color: colors.primary
                                                        .withAlpha(25),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
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
                                                  padding: const EdgeInsets.all(
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
                                      onChanged(
                                        snippet.copyWith(imageUrl: text),
                                      );
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

    final rawTextController = useTextEditingController(text: snippet.rawText);
    final latexController = useTextEditingController(
      text: snippet.latexContent ?? '',
    );
    final topicController = useTextEditingController(text: snippet.topic);

    void notifyUpdate() {
      onChanged(
        snippet.copyWith(
          rawText: rawTextController.text,
          latexContent: latexController.text.isNotEmpty
              ? latexController.text
              : null,
          topic: topicController.text,
          imageUrl: snippet.imageUrl,
        ),
      );
    }

    final hasImage =
        snippet.imageUrl != null && snippet.imageUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: hasImage
              ? colors.primary.withAlpha(isDark ? 90 : 50)
              : colors.primary.withAlpha(isDark ? 60 : 30),
          width: hasImage ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Question / Prompt Input & Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Text(
                  l10n.cardQuestionBadge,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: colors.success.withAlpha(isDark ? 100 : 60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_rounded,
                        size: 11,
                        color: colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DIAGRAM',
                        style: typography.caption.bold.copyWith(
                          color: colors.success,
                          fontSize: 9.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: topicController,
                  onChanged: (_) => notifyUpdate(),
                  style: typography.footnote.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.cardQuestionHint,
                    hintStyle: typography.footnote.regular.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Prominent Visual Diagram Preview (Placed directly under Question)
          if (hasImage) ...[
            const SizedBox(height: 12),
            Container(
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
                                      : Colors.transparent,
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
                                  onPressed: () => _showDiagramPicker(context),
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
                                    : Colors.transparent,
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
                                onPressed: () {
                                  onChanged(
                                    snippet.copyWith(clearImageUrl: true),
                                  );
                                },
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
                                imageUrl: snippet.imageUrl!,
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
            ),
          ] else if (availableImageUrls.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      onTap: () => _showDiagramPicker(context),
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
            ),
          ],

          const Divider(height: 20),

          // Answer / Explanation Input
          Text(
            l10n.cardAnswerLabel,
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: rawTextController,
            maxLines: 4,
            minLines: 2,
            onChanged: (_) => notifyUpdate(),
            style: typography.body.regular.copyWith(
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? colors.backgroundSecondary.withAlpha(120)
                  : colors.backgroundPrimary,
              hintText: l10n.cardAnswerHint,
              hintStyle: typography.body.regular.copyWith(
                color: colors.textMuted,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: BorderSide(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),

          // LaTeX Formula Input
          Text(
            l10n.cardEquationLabel,
            style: typography.caption.medium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: latexController,
            maxLines: 2,
            minLines: 1,
            onChanged: (_) => notifyUpdate(),
            style: typography.code.regular.copyWith(
              color: isDark ? colors.syllabotAccent : colors.primary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? colors.backgroundSecondary.withAlpha(120)
                  : colors.backgroundPrimary,
              hintText: l10n.cardEquationHint,
              hintStyle: typography.code.regular.copyWith(
                color: colors.textMuted,
                fontSize: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: BorderSide(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // Live LaTeX Math Preview
          if (latexController.text.isNotEmpty) ...[
            Text(
              l10n.liveFormulaPreviewLabel,
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.black.withAlpha(80)
                    : colors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 60 : 30),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  latexController.text
                      .replaceAll(r'$$', '')
                      .replaceAll(r'$', '')
                      .trim(),
                  textStyle: typography.body.bold.copyWith(
                    color: isDark ? colors.syllabotAccent : colors.primary,
                    fontSize: 16,
                  ),
                  onErrorFallback: (err) => Text(
                    latexController.text,
                    style: typography.caption.medium.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
