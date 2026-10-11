import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_formula_sheets.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_submission_coordinator.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_discussion_toolbar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Problem Statement & Working Steps editor container with toolbar and rich preview toggle.
class CreateDiscussionEditorSection extends StatelessWidget {
  const CreateDiscussionEditorSection({
    required this.titleController,
    required this.contentController,
    required this.isRichPreview,
    required this.isGeneratingAi,
    required this.onApplyFormatting,
    required this.onInsertSnippet,
    this.streamSyllabotResponseUseCase,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final ValueNotifier<bool> isRichPreview;
  final ValueNotifier<bool> isGeneratingAi;
  final void Function(String prefix, [String suffix]) onApplyFormatting;
  final ValueChanged<String> onInsertSnippet;
  final StreamSyllabotResponseUseCase? streamSyllabotResponseUseCase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Problem Statement & Working Steps',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
                fontSize: 11.5,
              ),
            ),
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                isRichPreview.value = !isRichPreview.value;
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRichPreview.value
                        ? Icons.edit_note_rounded
                        : Icons.remove_red_eye_outlined,
                    size: 14,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRichPreview.value ? 'Editor' : 'Rich Preview',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 35 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreateDiscussionToolbar(
                onApplyFormatting: onApplyFormatting,
                onShowMathFormulas: () =>
                    CreateDiscussionFormulaSheets.showMathFormulaSheet(
                      context,
                      onInsert: onInsertSnippet,
                    ),
                onShowSymbols: () =>
                    CreateDiscussionFormulaSheets.showSymbolSheet(
                      context,
                      onInsert: onInsertSnippet,
                    ),
                onRunAiFormatAssist: () =>
                    CreateDiscussionSubmissionCoordinator.runAiFormatAssist(
                      context: context,
                      titleController: titleController,
                      contentController: contentController,
                      isGeneratingAi: isGeneratingAi,
                      streamUseCase: streamSyllabotResponseUseCase,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: isRichPreview.value
                    ? (contentController.text.trim().isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Text(
                                'No content to preview yet. Switch to Editor to type.',
                                style: typography.body.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            )
                          : LatexRichViewer(
                              text: contentController.text,
                            ))
                    : TextField(
                        controller: contentController,
                        maxLines: null,
                        minLines: 6,
                        style: typography.body.regular.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Explain what you are solving, working steps, equations, or code...',
                          hintStyle: typography.body.regular.copyWith(
                            color: colors.textSecondary.withAlpha(120),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
