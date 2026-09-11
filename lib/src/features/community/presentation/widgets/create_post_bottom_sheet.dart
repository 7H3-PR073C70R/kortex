import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CreatePostBottomSheet extends HookWidget {
  const CreatePostBottomSheet({
    required this.onSubmit,
    this.lockedTrack,
    super.key,
  });

  final void Function({
    required String title,
    required String content,
    required String track,
    String? latexContent,
    bool isQuestion,
    String syllabusTag,
    bool isAnonymous,
  })
  onSubmit;

  final String? lockedTrack;

  static Future<void> show(
    BuildContext context, {
    required void Function({
      required String title,
      required String content,
      required String track,
      String? latexContent,
      bool isQuestion,
      String syllabusTag,
      bool isAnonymous,
    })
    onSubmit,
    String? lockedTrack,
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
        child: CreatePostBottomSheet(
          onSubmit: onSubmit,
          lockedTrack: lockedTrack,
        ),
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
    final syllabusTagController = useTextEditingController();
    final isQuestion = useState<bool>(false);
    final isAnonymous = useState<bool>(false);

    final authState = context.watch<AuthBloc?>()?.state;
    final userTrack = authState?.userProfile?.targetTrack;
    final activeTrack = (lockedTrack != null && lockedTrack!.trim().isNotEmpty)
        ? lockedTrack!.trim()
        : ((userTrack != null && userTrack.trim().isNotEmpty)
            ? userTrack.trim()
            : 'General');

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
              isQuestion.value ? 'Ask Cohort a Question' : l10n.createPostButton,
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Post Type Toggle: Discussion vs Question Bounty
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => isQuestion.value = false,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isQuestion.value
                              ? colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Discussion / Notes',
                            style: typography.caption.bold.copyWith(
                              color: !isQuestion.value
                                  ? colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => isQuestion.value = true,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isQuestion.value
                              ? colors.warning
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 14,
                              color: isQuestion.value
                                  ? colors.black
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Question Bounty',
                              style: typography.caption.bold.copyWith(
                                color: isQuestion.value
                                    ? colors.black
                                    : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Title Field
            AppTextField(
              controller: titleController,
              hintText: isQuestion.value
                  ? 'e.g. How do I solve this JAMB 2023 Physics Question 14?'
                  : l10n.postTitleHint,
            ),
            const SizedBox(height: 12),

            // Content Field
            AppTextField(
              controller: contentController,
              hintText: isQuestion.value
                  ? 'Detail the problem, what you tried, and where you are stuck...'
                  : l10n.postContentHint,
              maxLines: 4,
            ),
            const SizedBox(height: 12),

            // Optional Syllabus Tag Field
            AppTextField(
              controller: syllabusTagController,
              hintText: 'Syllabus Topic (e.g. Thermodynamics, Calculus I)',
            ),
            const SizedBox(height: 12),

            // Optional LaTeX Field
            AppTextField(
              controller: latexController,
              hintText: r'Optional LaTeX formula (e.g. \int_0^\infty e^{-x^2} dx)',
            ),
            const SizedBox(height: 14),

            // Ask Anonymously Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: isAnonymous.value
                        ? colors.primary
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Anonymously',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Hide name & avatar to ask questions with zero judgment.',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isAnonymous.value,
                    activeTrackColor: colors.primary,
                    onChanged: (val) {
                      isAnonymous.value = val;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ShrinkableButton(
              onTap: () {
                if (titleController.text.trim().isEmpty ||
                    contentController.text.trim().isEmpty) {
                  return;
                }
                final combinedText =
                    '${titleController.text} ${contentController.text}';
                final phoneRegex = RegExp(
                  r'(\+?\d{1,4}?[-.\s]?\(?\d{1,3}?\)?[-.\s]?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{1,9})',
                );
                if (phoneRegex.hasMatch(combinedText) &&
                    combinedText.replaceAll(RegExp(r'\D'), '').length >= 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'For student safety, sharing phone numbers or personal contact info is prohibited.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: colors.surfaceSecondary,
                    ),
                  );
                  return;
                }

                onSubmit(
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                  track: activeTrack,
                  latexContent: latexController.text.trim().isNotEmpty
                      ? latexController.text.trim()
                      : null,
                  isQuestion: isQuestion.value,
                  syllabusTag: syllabusTagController.text.trim().isNotEmpty
                      ? syllabusTagController.text.trim()
                      : 'General',
                  isAnonymous: isAnonymous.value,
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
                    isQuestion.value
                        ? 'Publish Question Bounty'
                        : l10n.createPostButton,
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
