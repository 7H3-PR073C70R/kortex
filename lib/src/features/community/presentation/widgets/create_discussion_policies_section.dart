import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Section configuring semantic tags and discussion policies (anonymity, AI hints, notifications).
class CreateDiscussionPoliciesSection extends StatelessWidget {
  const CreateDiscussionPoliciesSection({
    required this.tags,
    required this.onTagsChanged,
    required this.isAddingTag,
    required this.tagInputController,
    required this.isAnonymous,
    required this.onAnonymousChanged,
    required this.allowAiHints,
    required this.onAllowAiHintsChanged,
    required this.notifyVerifiedSolution,
    required this.onNotifyVerifiedSolutionChanged,
    super.key,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final ValueNotifier<bool> isAddingTag;
  final TextEditingController tagInputController;
  final bool isAnonymous;
  final ValueChanged<bool> onAnonymousChanged;
  final bool allowAiHints;
  final ValueChanged<bool> onAllowAiHintsChanged;
  final bool notifyVerifiedSolution;
  final ValueChanged<bool> onNotifyVerifiedSolutionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Semantic Tags Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Semantic Tags',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
                fontSize: 11.5,
              ),
            ),
            Text(
              'Max 5 tags (Optional)',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...tags.map(
                (tag) => Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$tag',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          onTagsChanged(tags.where((t) => t != tag).toList());
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tags.length < 5)
                if (isAddingTag.value)
                  Container(
                    width: 110,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceSecondary.withAlpha(160),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: TextField(
                        controller: tagInputController,
                        autofocus: true,
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'tag...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (val) {
                          final cleaned = val.replaceAll('#', '').trim();
                          if (cleaned.isNotEmpty && !tags.contains(cleaned)) {
                            onTagsChanged([...tags, cleaned]);
                          }
                          tagInputController.clear();
                          isAddingTag.value = false;
                        },
                      ),
                    ),
                  )
                else
                  ShrinkableButton(
                    onTap: () => isAddingTag.value = true,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceSecondary.withAlpha(120),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Add tag',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // DISCUSSION POLICIES
        Text(
          'DISCUSSION POLICIES',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
            fontSize: 10.5,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        // Policy 1: Post Anonymously
        _PolicyTile(
          icon: Icons.masks_rounded,
          iconColor: colors.primary,
          title: 'Post Anonymously',
          subtitle:
              'Hide your username and avatar from peers in this discussion thread',
          value: isAnonymous,
          onChanged: onAnonymousChanged,
        ),
        const SizedBox(height: 10),

        // Policy 2: AI hints in replies
        _PolicyTile(
          icon: Icons.lightbulb_outline_rounded,
          iconColor: colors.primary,
          title: 'Educational AI Hints in Replies',
          subtitle:
              'Allow student peers to generate structured AI explanations on this thread',
          value: allowAiHints,
          onChanged: onAllowAiHintsChanged,
        ),
        const SizedBox(height: 10),

        // Policy 3: Notify on verified solutions
        _PolicyTile(
          icon: Icons.notifications_active_outlined,
          iconColor: colors.success,
          title: 'Notify on Verified Solutions',
          subtitle:
              'Receive priority ping when a mentor validates the formula derivation',
          value: notifyVerifiedSolution,
          onChanged: onNotifyVerifiedSolutionChanged,
        ),
      ],
    );
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: value,
            activeColor: colors.primary,
            onChanged: (val) => onChanged(val ?? false),
          ),
        ],
      ),
    );
  }
}
