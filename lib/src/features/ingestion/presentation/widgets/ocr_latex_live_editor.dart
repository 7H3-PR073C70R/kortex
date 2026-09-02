import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';

class OcrLatexLiveEditor extends HookWidget {
  const OcrLatexLiveEditor({
    required this.snippet,
    required this.onChanged,
    super.key,
  });

  final OcrExtractionEntity snippet;
  final ValueChanged<OcrExtractionEntity> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final rawTextController = useTextEditingController(text: snippet.rawText);
    final latexController =
        useTextEditingController(text: snippet.latexContent ?? '');
    final topicController = useTextEditingController(text: snippet.topic);

    void notifyUpdate() {
      onChanged(
        snippet.copyWith(
          rawText: rawTextController.text,
          latexContent: latexController.text.isNotEmpty
              ? latexController.text
              : null,
          topic: topicController.text,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question / Prompt Input
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
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
                    ? Colors.black.withAlpha(80)
                    : colors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
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

          // Extracted Diagram Image Attachment Preview
          if (snippet.imageUrl != null && snippet.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.extractedVisualDiagramLabel,
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 160),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 60 : 30),
                  ),
                ),
                child: Image.network(
                  snippet.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_photo_outlined,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.visualDiagramLinkedLabel,
                          style: typography.footnote.regular
                              .copyWith(color: colors.textSecondary),
                        ),
                      ],
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
