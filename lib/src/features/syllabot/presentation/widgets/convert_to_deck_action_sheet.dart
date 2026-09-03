import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class ConvertToDeckActionSheet extends HookWidget {
  const ConvertToDeckActionSheet({
    required this.onGenerateDeck,
    this.initialTitle,
    this.initialCourseCode,
    super.key,
  });

  final void Function(String title, String courseCode) onGenerateDeck;
  final String? initialTitle;
  final String? initialCourseCode;

  static Future<void> show(
    BuildContext context, {
    required void Function(String title, String courseCode) onGenerateDeck,
    String? initialTitle,
    String? initialCourseCode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConvertToDeckActionSheet(
        onGenerateDeck: onGenerateDeck,
        initialTitle: initialTitle,
        initialCourseCode: initialCourseCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final titleController = useTextEditingController(
      text: initialTitle ?? 'Syllabot Study Notes',
    );
    final courseController = useTextEditingController(
      text: initialCourseCode ?? 'GEN 101',
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(240)
                  : colors.surfacePrimary.withAlpha(245),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.syllabotAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.style_rounded,
                        color: colors.syllabotAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.convertToDeckTitle,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.convertToDeckDescription,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Deck Title input
                AppTextField(
                  controller: titleController,
                  label: l10n.deckNameLabel,
                  hintText: l10n.convertDeckTitleHint,
                ),
                const SizedBox(height: 14),

                // Course Code input
                AppTextField(
                  controller: courseController,
                  label: 'Course Code / Tag',
                  hintText: 'e.g. PHYS 301',
                ),
                const SizedBox(height: 24),

                // Action Button
                AppButton(
                  text: l10n.createDeckAction,
                  prefixIcon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.heavyImpact());
                    Navigator.of(context).pop();
                    onGenerateDeck(
                      titleController.text.trim(),
                      courseController.text.trim(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
