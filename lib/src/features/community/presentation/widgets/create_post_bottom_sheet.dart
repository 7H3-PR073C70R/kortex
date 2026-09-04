import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CreatePostBottomSheet extends HookWidget {
  const CreatePostBottomSheet({
    required this.onSubmit,
    super.key,
  });

  final void Function({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  })
  onSubmit;

  static Future<void> show(
    BuildContext context, {
    required void Function({
      required String title,
      required String content,
      required String track,
      String? latexContent,
    })
    onSubmit,
  }) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      barrierColor: colors.black.withAlpha(isDark ? 160 : 100),
      builder: (sheetContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: CreatePostBottomSheet(onSubmit: onSubmit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final titleController = useTextEditingController();
    final contentController = useTextEditingController();
    final latexController = useTextEditingController();
    final selectedTrack = useState<String>('WAEC');

    final tracks = [
      'WAEC',
      'JAMB',
      'SAT',
      'Engineering',
      'Medicine',
      'General',
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfacePrimary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colors.primary.withAlpha(isDark ? 80 : 40),
            width: 1.2,
          ),
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
            Text(
              l10n.createPostButton,
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Track Selection Chips
            Text(
              l10n.selectTrackHint,
              style: typography.footnote.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: tracks.map((track) {
                final isSelected = selectedTrack.value == track;
                return ChoiceChip(
                  label: Text(track),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) selectedTrack.value = track;
                  },
                  selectedColor: colors.primary.withAlpha(50),
                  labelStyle: typography.caption.bold.copyWith(
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Title Field
            AppTextField(
              controller: titleController,
              hintText: l10n.postTitleHint,
            ),
            const SizedBox(height: 12),

            // Content Field
            AppTextField(
              controller: contentController,
              hintText: l10n.postContentHint,
              maxLines: 4,
            ),
            const SizedBox(height: 12),

            // Optional LaTeX Field
            AppTextField(
              controller: latexController,
              hintText: r'Optional LaTeX formula (e.g. \nabla \times E = 0)',
            ),
            const SizedBox(height: 20),

            // Submit Button
            ShrinkableButton(
              onTap: () {
                if (titleController.text.trim().isEmpty ||
                    contentController.text.trim().isEmpty) {
                  return;
                }
                onSubmit(
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                  track: selectedTrack.value,
                  latexContent: latexController.text.trim().isNotEmpty
                      ? latexController.text.trim()
                      : null,
                );
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withAlpha(220),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    l10n.createPostButton,
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
