import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
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
    final l10n = context.l10n;
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
                      AppTextField(
                        controller: frontController,
                        label: 'Front Prompt',
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: backController,
                        label: 'Back Answer / Explanation',
                        maxLines: 3,
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
                          if (card.imageUrl != null &&
                              card.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 120),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: colors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.primary.withAlpha(50),
                                  ),
                                ),
                                child: Image.network(
                                  card.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.insert_photo_outlined,
                                          size: 16,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.attachedDiagramLabel,
                                          style: typography.caption.medium
                                              .copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      )),
          ),
        ],
      ),
    );
  }
}
