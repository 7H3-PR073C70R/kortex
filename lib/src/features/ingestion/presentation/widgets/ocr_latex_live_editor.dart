import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

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
          // Topic Input
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.syllabotAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TOPIC',
                  style: typography.caption.bold.copyWith(
                    color: colors.syllabotAccent,
                    fontSize: 10,
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
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Enter topic name...',
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Raw Extracted Text Input
          Text(
            'Extracted Text / Explanation',
            style: typography.caption.medium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: rawTextController,
            maxLines: 3,
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

          // LaTeX Input
          Text(
            r'LaTeX Equation Block (e.g. $$\int f(x)dx$$)',
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
              'Live Formula Preview',
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
        ],
      ),
    );
  }
}
