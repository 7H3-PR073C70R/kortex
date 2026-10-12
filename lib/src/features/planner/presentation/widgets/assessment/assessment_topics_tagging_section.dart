import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Section for tagging specific syllabus topics and chapters for an assessment.
class AssessmentTopicsTaggingSection extends StatelessWidget {
  const AssessmentTopicsTaggingSection({
    required this.topicController,
    required this.scopedTopics,
    required this.onAddTopic,
    required this.onRemoveTopic,
    super.key,
  });

  final TextEditingController topicController;
  final List<String> scopedTopics;
  final VoidCallback onAddTopic;
  final ValueChanged<String> onRemoveTopic;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.topic_outlined,
                size: 15,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.scopedTopicsTitle,
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: topicController,
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.addTopicHint,
                    hintStyle: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colors.surfaceBorder,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onAddTopic(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: onAddTopic,
                style: IconButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.all(10),
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),
          if (scopedTopics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scopedTopics.map((topic) {
                return Chip(
                  label: Text(topic),
                  labelStyle: typography.caption.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 11.5,
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () => onRemoveTopic(topic),
                  backgroundColor: colors.primary.withAlpha(isDark ? 35 : 20),
                  side: BorderSide(
                    color: colors.primary.withAlpha(70),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
