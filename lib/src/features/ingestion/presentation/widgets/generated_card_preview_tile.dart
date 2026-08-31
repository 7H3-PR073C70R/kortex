import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class GeneratedCardPreviewTile extends HookWidget {
  const GeneratedCardPreviewTile({
    required this.index,
    required this.card,
    required this.onChanged,
    super.key,
  });

  final int index;
  final GeneratedCardPreviewItem card;
  final ValueChanged<GeneratedCardPreviewItem> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isFlipped = useState<bool>(false);
    final frontController = useTextEditingController(text: card.front);
    final backController = useTextEditingController(text: card.back);
    final isEditing = useState<bool>(false);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Index & Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'CARD #${index + 1}',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isEditing.value
                            ? Icons.check_rounded
                            : Icons.edit_outlined,
                        size: 16,
                        color: colors.primary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (isEditing.value) {
                          onChanged(
                            card.copyWith(
                              front: frontController.text,
                              back: backController.text,
                            ),
                          );
                        }
                        isEditing.value = !isEditing.value;
                      },
                    ),
                    const SizedBox(width: 8),
                    ShrinkableButton(
                      onTap: () => isFlipped.value = !isFlipped.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.syllabotAccent.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flip_rounded,
                              size: 12,
                              color: colors.syllabotAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFlipped.value ? 'Show Front' : 'Show Back',
                              style: typography.caption.medium.copyWith(
                                color: colors.syllabotAccent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Content body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: isEditing.value
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Front Prompt',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: frontController,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? colors.backgroundSecondary
                              : colors.backgroundPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Back Answer / Explanation',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: backController,
                        maxLines: 3,
                        style: typography.body.regular.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? colors.backgroundSecondary
                              : colors.backgroundPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  )
                : (isFlipped.value
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ANSWER / EXPLANATION',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.back,
                            style: typography.body.regular.copyWith(
                              color: colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          if (card.backLatex != null &&
                              card.backLatex!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                card.backLatex!
                                    .replaceAll(r'$$', '')
                                    .replaceAll(r'$', '')
                                    .trim(),
                                textStyle: typography.body.bold.copyWith(
                                  color: isDark
                                      ? colors.syllabotAccent
                                      : colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROMPT / CONCEPT',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.front,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      )),
          ),
        ],
      ),
    );
  }
}
