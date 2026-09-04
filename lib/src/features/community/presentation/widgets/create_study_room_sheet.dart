import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CreateStudyRoomSheet extends HookWidget {
  const CreateStudyRoomSheet({
    required this.onSubmit,
    super.key,
  });

  final void Function({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
  })
  onSubmit;

  static Future<void> show(
    BuildContext context, {
    required void Function({
      required String title,
      required String subject,
      required String category,
      required int pomodoroMinutes,
    })
    onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateStudyRoomSheet(onSubmit: onSubmit),
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
    final selectedCategory = useState<String>('STEM');
    final selectedDuration = useState<int>(25);

    const categories = [
      'STEM',
      'JAMB',
      'WAEC',
      'SAT',
      'Medicine',
      'Engineering',
      'General',
    ];

    const durations = [15, 25, 45, 50, 60];

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
                    Icons.timer_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Create Focus Room',
                  style: typography.title2.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Room Title Field
            AppTextField(
              controller: titleController,
              hintText: 'Room Title (e.g. Pure Math Problem Solving)',
            ),
            const SizedBox(height: 12),

            // Subject Field
            AppTextField(
              controller: subjectController,
              hintText: 'Subject / Course Code (e.g. MTH 301, Physics)',
            ),
            const SizedBox(height: 16),

            // Duration Selection
            Text(
              'Pomodoro Duration',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: durations.map((dur) {
                final isSelected = selectedDuration.value == dur;
                return ChoiceChip(
                  label: Text('${dur}m'),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      unawaited(HapticFeedback.lightImpact());
                      selectedDuration.value = dur;
                    }
                  },
                  selectedColor: colors.primary.withAlpha(40),
                  labelStyle: typography.caption.bold.copyWith(
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                );
              }).toList(),
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
                if (title.isEmpty || subject.isEmpty) return;

                unawaited(HapticFeedback.mediumImpact());
                onSubmit(
                  title: title,
                  subject: subject,
                  category: selectedCategory.value,
                  pomodoroMinutes: selectedDuration.value,
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
                    l10n.launchFocusRoom,
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
