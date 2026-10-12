import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Container for scoping flashcard decks associated with the selected course.
class AssessmentDecksSelectorSection extends StatelessWidget {
  const AssessmentDecksSelectorSection({
    required this.courseDecks,
    required this.selectedDeckIds,
    required this.onToggleDeck,
    required this.onSelectAll,
    required this.onClearAll,
    super.key,
  });

  final List<DeckEntity> courseDecks;
  final Set<String> selectedDeckIds;
  final ValueChanged<String> onToggleDeck;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (courseDecks.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(100)
            : colors.surfaceSecondary.withAlpha(70),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.scopedTopicsLabel,
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: onSelectAll,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Select All',
                      style: typography.caption.semiBold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onClearAll,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Clear',
                      style: typography.caption.semiBold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: courseDecks.map((deck) {
              final isSelected = selectedDeckIds.contains(deck.id);
              return FilterChip(
                label: Text('${deck.title} (${deck.totalCards})'),
                labelStyle: typography.caption.regular.copyWith(
                  color: isSelected ? colors.primary : colors.textSecondary,
                  fontSize: 12,
                ),
                selected: isSelected,
                showCheckmark: true,
                checkmarkColor: colors.primary,
                selectedColor: colors.primary.withAlpha(
                  isDark ? 40 : 25,
                ),
                backgroundColor: colors.transparent,
                side: BorderSide(
                  color: isSelected ? colors.primary : colors.surfaceBorder,
                ),
                onSelected: (_) => onToggleDeck(deck.id),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
