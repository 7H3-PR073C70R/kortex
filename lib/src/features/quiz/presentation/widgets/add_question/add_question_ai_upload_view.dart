import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// AI Document Upload and automated question calibration view.
class AddQuestionAiUploadView extends StatelessWidget {
  const AddQuestionAiUploadView({
    required this.pickedFile,
    required this.isCalibrating,
    required this.calibrationProgress,
    required this.calibrationStatus,
    required this.calibratedQuestions,
    required this.onPickFile,
    required this.onExecuteCalibration,
    required this.onSaveCalibrated,
    required this.isSubmitting,
    required this.courseCode,
    super.key,
  });

  final ValueNotifier<PickedDocument?> pickedFile;
  final bool isCalibrating;
  final double calibrationProgress;
  final String calibrationStatus;
  final List<PastQuestionEntity> calibratedQuestions;
  final VoidCallback onPickFile;
  final VoidCallback onExecuteCalibration;
  final VoidCallback onSaveCalibrated;
  final bool isSubmitting;
  final String courseCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final file = pickedFile.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Dropzone
        ShrinkableButton(
          onTap: isCalibrating ? null : onPickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(120)
                  : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: file != null ? colors.primary : colors.surfaceBorder,
                width: file != null ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    file != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 28,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                if (file == null) ...[
                  Text(
                    'Upload Past Paper (PDF, Images, TXT)',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Extracts MCQs & theory questions, solves answers & explains reasoning.',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ] else ...[
                  Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(file.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB • Ready for AI',
                    style: typography.footnote.regular.copyWith(
                      color: colors.success,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Calibration Progress
        if (isCalibrating) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppLogoLoader(size: 16, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        calibrationStatus,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: calibrationProgress,
                  backgroundColor: colors.primary.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (calibratedQuestions.isEmpty)
          AppButton(
            text: isCalibrating
                ? 'Analyzing & Calibrating...'
                : 'Extract & Calibrate with AI',
            isLoading: isCalibrating,
            onPressed: isCalibrating || file == null
                ? null
                : onExecuteCalibration,
            prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 16),
          )
        else ...[
          // Calibrated questions preview summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.success.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted ${calibratedQuestions.length} Questions (${calibratedQuestions.where((q) => !q.isTheory).length} MCQ, ${calibratedQuestions.where((q) => q.isTheory).length} Theory)',
                    style: typography.caption.bold.copyWith(
                      color: colors.success,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Calibrated Question Previews
          ...calibratedQuestions.take(5).map((q) {
            final isTheory = q.isTheory;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isTheory
                              ? colors.syllabotAccent.withAlpha(30)
                              : colors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Text(
                          isTheory ? 'THEORY / ESSAY' : 'MULTIPLE CHOICE',
                          style: typography.caption.bold.copyWith(
                            color: isTheory
                                ? colors.syllabotAccent
                                : colors.primary,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                      if (!isTheory)
                        Text(
                          'Correct: ${q.correctOptionLabel}',
                          style: typography.caption.bold.copyWith(
                            color: colors.success,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.prompt,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 12.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    q.explanation,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          AppButton(
            text: 'Save ${calibratedQuestions.length} Questions to $courseCode',
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onSaveCalibrated,
            prefixIcon: const Icon(Icons.bookmark_added_rounded, size: 16),
          ),
        ],
      ],
    );
  }
}
