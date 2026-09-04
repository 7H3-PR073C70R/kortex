import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class PublishDeckModalSheet extends HookWidget {
  const PublishDeckModalSheet({
    required this.onSubmit,
    super.key,
  });

  final void Function({
    required String title,
    required String subject,
    required String description,
    required String category,
  })
  onSubmit;

  static Future<void> show(
    BuildContext context, {
    required void Function({
      required String title,
      required String subject,
      required String description,
      required String category,
    })
    onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (ctx) => PublishDeckModalSheet(onSubmit: onSubmit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final titleController = useTextEditingController();
    final subjectController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedCategory = useState<String>('STEM');

    const categories = [
      'STEM',
      'JAMB',
      'WAEC',
      'SAT',
      'Medicine',
      'Engineering',
      'General',
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfacePrimary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 30),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grabber handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Sheet Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Share Deck to Marketplace',
                  style: typography.title2.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Deck Title
            AppTextField(
              controller: titleController,
              hintText: 'Deck Title (e.g. Organic Chemistry Reactions)',
            ),
            const SizedBox(height: 12),

            // Subject
            AppTextField(
              controller: subjectController,
              hintText: 'Subject / Track (e.g. Chemistry, JAMB)',
            ),
            const SizedBox(height: 12),

            // Description
            AppTextField(
              controller: descriptionController,
              hintText: 'Brief description of concepts covered...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Category Selection
            Text(
              'Category / Track',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: categories.map((cat) {
                final isSelected = selectedCategory.value == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      unawaited(HapticFeedback.lightImpact());
                      selectedCategory.value = cat;
                    }
                  },
                  selectedColor: colors.primary.withAlpha(40),
                  labelStyle: typography.caption.bold.copyWith(
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // Submit Button
            ShrinkableButton(
              onTap: () {
                final title = titleController.text.trim();
                final subject = subjectController.text.trim();
                final desc = descriptionController.text.trim();
                if (title.isEmpty || subject.isEmpty) return;

                unawaited(HapticFeedback.mediumImpact());
                onSubmit(
                  title: title,
                  subject: subject,
                  description: desc.isNotEmpty ? desc : 'Community Deck',
                  category: selectedCategory.value,
                );
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withAlpha(220),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 80 : 50),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    l10n.shareDeckTitle,
                    style: typography.body.bold.copyWith(
                      color: colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
