import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Manual form entry for creating a multiple-choice or theory past question.
class AddQuestionManualFormView extends StatelessWidget {
  const AddQuestionManualFormView({
    required this.isTheoryMode,
    required this.promptController,
    required this.optionAController,
    required this.optionBController,
    required this.optionCController,
    required this.optionDController,
    required this.correctOptionLabel,
    required this.explanationController,
    required this.topicController,
    required this.attachedImagePath,
    required this.onSaveQuestion,
    required this.isSubmitting,
    required this.courseCode,
    required this.courseTitle,
    required this.courseId,
    required this.mappedSubject,
    required this.examCategory,
    required this.effectiveYear,
    super.key,
  });

  final ValueNotifier<bool> isTheoryMode;
  final TextEditingController promptController;
  final TextEditingController optionAController;
  final TextEditingController optionBController;
  final TextEditingController optionCController;
  final TextEditingController optionDController;
  final ValueNotifier<String> correctOptionLabel;
  final TextEditingController explanationController;
  final TextEditingController topicController;
  final ValueNotifier<String?> attachedImagePath;
  final void Function(PastQuestionEntity) onSaveQuestion;
  final bool isSubmitting;
  final String courseCode;
  final String courseTitle;
  final String courseId;
  final String mappedSubject;
  final ExamCategory examCategory;
  final int effectiveYear;

  void _validateAndSubmit(BuildContext context) {
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      context.showSnackBar(
        message: 'Please enter the question prompt.',
      );
      return;
    }

    final isTheory = isTheoryMode.value;
    final options = <String>[];
    var correctIdx = 0;
    var correctLabel = 'A';

    if (!isTheory) {
      final optA = optionAController.text.trim();
      final optB = optionBController.text.trim();
      final optC = optionCController.text.trim();
      final optD = optionDController.text.trim();

      if (optA.isEmpty || optB.isEmpty) {
        context.showSnackBar(
          message: 'Please provide at least Option A and Option B.',
        );
        return;
      }

      final optList = ['A. $optA', 'B. $optB'];
      if (optC.isNotEmpty) optList.add('C. $optC');
      if (optD.isNotEmpty) optList.add('D. $optD');
      options.addAll(optList);

      correctLabel = correctOptionLabel.value;
      correctIdx = [
        'A',
        'B',
        'C',
        'D',
      ].indexOf(correctLabel).clamp(0, options.length - 1);
    }

    final newQuestion = PastQuestionEntity(
      id: 'pq_user_${UuidUtils.generate()}',
      examType: examCategory,
      subject: mappedSubject,
      year: effectiveYear,
      questionNumber: 1,
      prompt: prompt,
      options: options,
      correctOptionIndex: correctIdx,
      correctOptionLabel: isTheory ? '' : correctLabel,
      explanation: explanationController.text.trim().isNotEmpty
          ? explanationController.text.trim()
          : (isTheory
              ? 'Model answer verified for $courseCode.'
              : 'Option $correctLabel is verified based on curriculum standards.'),
      topic: topicController.text.trim().isNotEmpty
          ? topicController.text.trim()
          : courseTitle,
      imageUrl: attachedImagePath.value,
      isUserAdded: true,
      courseId: courseId,
      courseCode: courseCode,
    );

    onSaveQuestion(newQuestion);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ValueListenableBuilder<bool>(
      valueListenable: isTheoryMode,
      builder: (context, isTheory, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Mode Selector: Multiple Choice vs Theory
        Row(
          children: [
            Expanded(
              child: ShrinkableButton(
                onTap: () {
                  AppFeedback.selection();
                  isTheoryMode.value = false;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !isTheory
                        ? colors.primary.withAlpha(25)
                        : (isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceBorder.withAlpha(50)),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: !isTheory ? colors.primary : colors.surfaceBorder,
                      width: !isTheory ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Multiple Choice (MCQ)',
                      style: typography.caption.bold.copyWith(
                        color: !isTheory
                            ? colors.primary
                            : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShrinkableButton(
                onTap: () {
                  AppFeedback.selection();
                  isTheoryMode.value = true;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isTheory
                        ? colors.syllabotAccent.withAlpha(25)
                        : (isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceBorder.withAlpha(50)),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: isTheory
                          ? colors.syllabotAccent
                          : colors.surfaceBorder,
                      width: isTheory ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Theory / Essay',
                      style: typography.caption.bold.copyWith(
                        color: isTheory
                            ? colors.syllabotAccent
                            : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Prompt
        Text(
          'Question Stem / Problem Statement',
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: promptController,
          hintText: isTheory
              ? 'State, explain, or derive the problem statement...'
              : 'What is the correct definition / answer for...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // MCQ Options
        if (!isTheory) ...[
          Text(
            'Options & Correct Answer',
            style: typography.caption.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _buildOptionField(
            'A',
            optionAController,
            correctOptionLabel,
            colors,
            typography,
          ),
          const SizedBox(height: 8),
          _buildOptionField(
            'B',
            optionBController,
            correctOptionLabel,
            colors,
            typography,
          ),
          const SizedBox(height: 8),
          _buildOptionField(
            'C',
            optionCController,
            correctOptionLabel,
            colors,
            typography,
          ),
          const SizedBox(height: 8),
          _buildOptionField(
            'D',
            optionDController,
            correctOptionLabel,
            colors,
            typography,
          ),
          const SizedBox(height: 14),
        ],

        // Explanation / Model Answer
        Text(
          isTheory
              ? 'Model Answer, Rubric & Rationale'
              : 'Explanation (Why that is the answer)',
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: explanationController,
          hintText: isTheory
              ? 'Provide the complete model solution, formulas, and key points...'
              : 'Detailed step-by-step reasoning explaining why this answer is correct...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // Topic
        Text(
          'Specific Topic / Syllabus Unit',
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: topicController,
          hintText: 'e.g. Data Structures, Thermodynamics',
        ),
        const SizedBox(height: 14),

        // Image Attachment (Optional)
        ValueListenableBuilder<String?>(
          valueListenable: attachedImagePath,
          builder: (context, imagePath, _) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    imagePath != null
                        ? 'Diagram: ${imagePath.split('/').last}'
                        : 'Optional Diagram Attachment',
                    style: typography.caption.medium.copyWith(
                      color: imagePath != null
                          ? colors.primary
                          : colors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    AppFeedback.light();
                    final doc = await FilePickerService().pickStudyDocument(
                      extensions: const ['png', 'jpg', 'jpeg'],
                    );
                    if (doc != null && doc.path != null) {
                      attachedImagePath.value = doc.path;
                    }
                  },
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: Text(
                    imagePath != null ? 'Change' : 'Add Diagram',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (imagePath != null)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 16, color: colors.error),
                    onPressed: () {
                      attachedImagePath.value = null;
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        AppButton(
          text: isSubmitting
              ? 'Saving Question...'
              : 'Save Question to $courseCode',
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : () => _validateAndSubmit(context),
          prefixIcon: const Icon(Icons.add_task_rounded, size: 16),
        ),
      ],
    );
      },
    );
  }

  Widget _buildOptionField(
    String letter,
    TextEditingController controller,
    ValueNotifier<String> selectedCorrect,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    return Row(
      children: [
        ValueListenableBuilder<String>(
          valueListenable: selectedCorrect,
          builder: (context, currentChoice, _) {
            final isCorrect = currentChoice == letter;
            return ShrinkableButton(
              onTap: () {
                AppFeedback.selection();
                selectedCorrect.value = letter;
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCorrect
                      ? colors.success
                      : colors.surfaceBorder.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: typography.caption.bold.copyWith(
                      color: isCorrect ? colors.white : colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppTextField(
            controller: controller,
            hintText: 'Option $letter',
          ),
        ),
      ],
    );
  }
}
