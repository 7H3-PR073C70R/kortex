import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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
    final hasImage = card.imageUrl != null && card.imageUrl!.trim().isNotEmpty;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: AppMotion.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: isEditing.value 
                  ? colors.primary.withAlpha(120)
                  : hasImage
                      ? colors.primary.withAlpha(isDark ? 90 : 50)
                      : colors.primary.withAlpha(isDark ? 40 : 20),
              width: isEditing.value ? 2.0 : (hasImage ? 1.4 : 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? (isHovered ? 40 : 20) : (isHovered ? 15 : 5)),
                blurRadius: isHovered ? 16 : 8,
                offset: Offset(0, isHovered ? 6 : 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Index & Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                      child: Text(
                        'CARD #${index + 1}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.success.withAlpha(isDark ? 40 : 25),
                          borderRadius: AppRadius.radiusMicro,
                          border: Border.all(
                            color: colors.success.withAlpha(isDark ? 90 : 50),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_rounded,
                              size: 10,
                              color: colors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DIAGRAM',
                              style: typography.caption.bold.copyWith(
                                color: colors.success,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedScale(
                          scale: isHovered ? 1.12 : 1.0,
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          child: child,
                        );
                      },
                      child: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return RotationTransition(
                              turns: child.key == const ValueKey('icon_check') 
                                  ? Tween<double>(begin: -0.2, end: 0).animate(animation)
                                  : Tween<double>(begin: 0.2, end: 0).animate(animation),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: Icon(
                            isEditing.value
                                ? Icons.check_rounded
                                : Icons.edit_outlined,
                            key: ValueKey(isEditing.value ? 'icon_check' : 'icon_edit'),
                            size: 16,
                            color: isEditing.value ? colors.success : colors.primary,
                          ),
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
                    ),
                    const SizedBox(width: 12),
                    PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedScale(
                          scale: isHovered ? 1.05 : 1.0,
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          child: child,
                        );
                      },
                      child: ShrinkableButton(
                        onTap: () => isFlipped.value = !isFlipped.value,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isFlipped.value ? colors.syllabotAccent.withAlpha(40) : colors.syllabotAccent.withAlpha(isDark ? 25 : 15),
                            borderRadius: AppRadius.radiusBadge,
                            border: Border.all(
                              color: isFlipped.value ? colors.syllabotAccent.withAlpha(60) : colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFlipped.value ? Icons.flip_to_back_rounded : Icons.flip_to_front_rounded,
                                size: 12,
                                color: colors.syllabotAccent,
                              ),
                              const SizedBox(width: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: Text(
                                  isFlipped.value ? 'Back' : 'Front',
                                  key: ValueKey(isFlipped.value),
                                  style: typography.caption.bold.copyWith(
                                    color: colors.syllabotAccent,
                                    fontSize: 11,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 24, color: colors.primary.withAlpha(isDark ? 30 : 15)),

          // Content body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              child: isEditing.value
                  ? Column(
                      key: const ValueKey('edit_view'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: frontController,
                          label: 'Front Prompt',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: backController,
                          label: 'Back Answer / Explanation',
                          maxLines: 3,
                        ),
                      ],
                    )
                  : (isFlipped.value
                        ? Column(
                            key: const ValueKey('back_view'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ANSWER / EXPLANATION',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary.withAlpha(160),
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.back,
                                style: typography.body.regular.copyWith(
                                  color: colors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                              if (card.backLatex != null &&
                                  card.backLatex!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(isDark ? 20 : 10),
                                    borderRadius: AppRadius.radiusCard,
                                    border: Border.all(
                                      color: colors.primary.withAlpha(isDark ? 40 : 20),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
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
                                ),
                              ],
                            ],
                          )
                        : Column(
                            key: const ValueKey('front_view'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROMPT / CONCEPT',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary.withAlpha(160),
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.front,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              if (card.imageUrl != null &&
                                  card.imageUrl!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: AppRadius.radiusCard,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 180,
                                    ),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? colors.surfaceSecondary
                                          : colors.backgroundSecondary.withAlpha(120),
                                      borderRadius: AppRadius.radiusCard,
                                      border: Border.all(
                                        color: colors.primary.withAlpha(isDark ? 60 : 30),
                                      ),
                                    ),
                                    child: AppMultimodalImage(
                                      imageUrl: card.imageUrl!,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )),
            ),
          ),
        ],
      ),
    );
  }
}
