import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_editor/diagram_picker_modal_sheet.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_editor/extracted_diagram_preview_section.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_editor/latex_math_preview_box.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

export 'ocr_editor/diagram_picker_modal_sheet.dart';
export 'ocr_editor/extracted_diagram_preview_section.dart';
export 'ocr_editor/latex_math_preview_box.dart';

/// Live interactive editor card for OCR extracted snippets, supporting real-time
/// LaTeX formula preview, diagram attachment, and question/answer modifications.
class OcrLatexLiveEditor extends HookWidget {
  const OcrLatexLiveEditor({
    required this.snippet,
    required this.onChanged,
    this.availableImageUrls = const [],
    this.cardNumber,
    this.onDelete,
    super.key,
  });

  final OcrExtractionEntity snippet;
  final ValueChanged<OcrExtractionEntity> onChanged;
  final List<String> availableImageUrls;
  final int? cardNumber;
  final VoidCallback? onDelete;

  void _showDiagramPicker(BuildContext context) {
    unawaited(
      showDiagramPickerModalSheet(
        context,
        availableImageUrls: availableImageUrls,
        selectedImageUrl: snippet.imageUrl,
        onImageSelected: (imgUrl) {
          onChanged(snippet.copyWith(imageUrl: imgUrl));
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

    useListenable(latexController);

    useEffect(() {
      if (rawTextController.text != snippet.rawText) {
        rawTextController.text = snippet.rawText;
      }
      if (latexController.text != (snippet.latexContent ?? '')) {
        latexController.text = snippet.latexContent ?? '';
      }
      if (topicController.text != snippet.topic) {
        topicController.text = snippet.topic;
      }
      return null;
    }, [snippet.rawText, snippet.latexContent, snippet.topic]);

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
                  cardNumber != null
                      ? 'CARD #$cardNumber'
                      : l10n.cardQuestionBadge,
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
              if (onDelete != null)
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isHovered
                            ? colors.error.withAlpha(25)
                            : context.colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: isHovered ? colors.error : colors.textMuted,
                        ),
                        tooltip: 'Delete Card',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onDelete,
                      ),
                    );
                  },
                ),
            ],
          ),

          // Prominent Visual Diagram Preview
          ExtractedDiagramPreviewSection(
            imageUrl: snippet.imageUrl,
            availableImageUrls: availableImageUrls,
            onAttachDiagramTap: () => _showDiagramPicker(context),
            onSwapDiagramTap: () => _showDiagramPicker(context),
            onRemoveDiagramTap: () {
              onChanged(snippet.copyWith(clearImageUrl: true));
            },
          ),

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
          Row(
            children: [
              Text(
                l10n.cardEquationLabel,
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              if (latexController.text.isEmpty &&
                  snippet.rawText.contains(RegExp(r'[\=\+\-\*\/\^\\]')))
                InkWell(
                  onTap: () {
                    final match = RegExp(
                      r'([A-Za-z0-9_\^\+\-\*\/\=\(\)\\\s]{3,}\s*=\s*[A-Za-z0-9_\^\+\-\*\/\(\)\\\s]+)',
                    ).firstMatch(snippet.rawText);
                    if (match != null) {
                      latexController.text = match.group(0)!.trim();
                      notifyUpdate();
                    }
                  },
                  child: Text(
                    'Extract formula from text',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
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
          LatexMathPreviewBox(
            latexFormula: latexController.text,
            onRetryCleaned: (cleaned) {
              latexController.text = cleaned;
              notifyUpdate();
            },
          ),
        ],
      ),
    );
  }
}
