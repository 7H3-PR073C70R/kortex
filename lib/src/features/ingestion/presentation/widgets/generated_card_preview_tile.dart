import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class GeneratedCardPreviewTile extends HookWidget {
  const GeneratedCardPreviewTile({
    required this.index,
    required this.card,
    required this.onChanged,
    this.onDelete,
    super.key,
  });

  final int index;
  final GeneratedCardPreviewItem card;
  final ValueChanged<GeneratedCardPreviewItem> onChanged;
  final VoidCallback? onDelete;

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
    final hasLatex =
        (card.backLatex != null && card.backLatex!.trim().isNotEmpty) ||
            (card.frontLatex != null && card.frontLatex!.trim().isNotEmpty);

    useEffect(() {
      frontController.text = card.front;
      backController.text = card.back;
      return null;
    }, [card.front, card.back]);

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: AppMotion.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: isEditing.value
                  ? colors.primary
                  : hasImage
                      ? colors.primary.withAlpha(isDark ? 90 : 50)
                      : (isDark
                          ? colors.surfaceBorderHighlight.withAlpha(50)
                          : colors.surfaceBorder.withAlpha(120)),
              width: isEditing.value ? 1.8 : (hasImage ? 1.4 : 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(
                  isDark ? (isHovered ? 40 : 20) : (isHovered ? 14 : 5),
                ),
                blurRadius: isHovered ? 14 : 6,
                offset: Offset(0, isHovered ? 4 : 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Badges + Action Buttons ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                // Left — badges, wrapped so they never overflow on small screens
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Card index badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 35 : 20),
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

                      // Diagram badge
                      if (hasImage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.success.withAlpha(isDark ? 35 : 20),
                            borderRadius: AppRadius.radiusMicro,
                            border: Border.all(
                              color:
                                  colors.success.withAlpha(isDark ? 80 : 40),
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

                      // Math badge
                      if (hasLatex)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.latexHighlight
                                .withAlpha(isDark ? 35 : 20),
                            borderRadius: AppRadius.radiusMicro,
                            border: Border.all(
                              color: colors.latexHighlight
                                  .withAlpha(isDark ? 80 : 40),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.functions_rounded,
                                size: 10,
                                color: colors.latexHighlight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'MATH',
                                style: typography.caption.bold.copyWith(
                                  color: colors.latexHighlight,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right — compact icon-only action buttons (never overflow)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flip Front/Back
                    _ActionIconButton(
                      tooltip: isFlipped.value
                          ? 'Showing Back — tap to flip'
                          : 'Showing Front — tap to flip',
                      onTap: () => isFlipped.value = !isFlipped.value,
                      icon: isFlipped.value
                          ? Icons.flip_to_back_rounded
                          : Icons.flip_to_front_rounded,
                      backgroundColor: isFlipped.value
                          ? colors.syllabotAccent.withAlpha(isDark ? 50 : 30)
                          : colors.syllabotAccent.withAlpha(isDark ? 25 : 12),
                      iconColor: colors.syllabotAccent,
                      hasBorder: isFlipped.value,
                      borderColor: colors.syllabotAccent.withAlpha(80),
                    ),
                    const SizedBox(width: 6),

                    // Edit / Done
                    _ActionIconButton(
                      tooltip:
                          isEditing.value ? 'Save changes' : 'Edit this card',
                      onTap: () {
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
                      icon: isEditing.value
                          ? Icons.check_rounded
                          : Icons.edit_outlined,
                      backgroundColor: isEditing.value
                          ? colors.success.withAlpha(isDark ? 40 : 25)
                          : colors.primary.withAlpha(isDark ? 30 : 15),
                      iconColor:
                          isEditing.value ? colors.success : colors.primary,
                    ),

                    // Delete (optional)
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      _ActionIconButton(
                        tooltip: 'Delete card',
                        onTap: onDelete,
                        icon: Icons.delete_outline_rounded,
                        backgroundColor:
                            colors.error.withAlpha(isDark ? 30 : 15),
                        iconColor: colors.error,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          Divider(
            height: 20,
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(50)
                : colors.surfaceBorder.withAlpha(100),
          ),

          // ─── Content Body ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                            LatexRichViewer(
                              text: card.back,
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
                                  color: colors.primary
                                      .withAlpha(isDark ? 20 : 10),
                                  borderRadius: AppRadius.radiusCard,
                                  border: Border.all(
                                    color: colors.primary
                                        .withAlpha(isDark ? 40 : 20),
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
                            LatexRichViewer(
                              text: card.front,
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
                                        : colors.backgroundSecondary
                                            .withAlpha(120),
                                    borderRadius: AppRadius.radiusCard,
                                    border: Border.all(
                                      color: colors.primary
                                          .withAlpha(isDark ? 60 : 30),
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

// ─── Private helper widget for compact action icon buttons ────────────────────
class _ActionIconButton extends HookWidget {
  const _ActionIconButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.hasBorder = false,
    this.borderColor,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final bool hasBorder;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return AnimatedScale(
            scale: isHovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
        child: ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadius.radiusMicro,
              border: hasBorder
                  ? Border.all(
                      color: borderColor ?? colors.transparent,
                    )
                  : null,
            ),
            child: Icon(
              icon,
              size: 15,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
