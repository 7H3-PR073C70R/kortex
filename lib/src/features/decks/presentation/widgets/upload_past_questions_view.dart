import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class UploadPastQuestionsView extends StatelessWidget {
  const UploadPastQuestionsView({
    required this.pickedFile,
    required this.isCalibrating,
    required this.statusText,
    required this.progress,
    required this.onExecuteCalibration,
    super.key,
  });

  final ValueNotifier<PickedDocument?> pickedFile;
  final bool isCalibrating;
  final String statusText;
  final double progress;
  final VoidCallback onExecuteCalibration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Past Questions Asset',
          style: typography.callout.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Our AI engine will parse the document, extract question stems & options, calibrate verified answers, and register them into the global Question Bank.',
          style: typography.footnote.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),

        // Dropzone / File Picker Container
        ShrinkableButton(
          onTap: isCalibrating
              ? null
              : () async {
                  AppFeedback.light();
                  final doc = await FilePickerService().pickStudyDocument(
                    extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'pptx'],
                  );
                  if (doc != null) {
                    pickedFile.value = doc;
                  }
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(120)
                  : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: pickedFile.value != null
                    ? colors.primary
                    : (isDark ? colors.surfaceBorderHighlight.withAlpha(60) : colors.surfaceBorder),
                width: pickedFile.value != null ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 45 : 25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pickedFile.value != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (pickedFile.value == null) ...[
                  Text(
                    'Select PDF or Document Asset',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to browse PDF past papers, exam snapshots, or lecture notes (Max 50MB)',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ] else ...[
                  Text(
                    pickedFile.value!.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(pickedFile.value!.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB • Ready for AI calibration',
                    style: typography.footnote.regular.copyWith(
                      color: colors.success,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      AppFeedback.light();
                      pickedFile.value = null;
                    },
                    icon: Icon(Icons.close_rounded, size: 16, color: colors.error),
                    label: Text(
                      'Remove File',
                      style: typography.caption.bold.copyWith(
                        color: colors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Progress bar during calibration
        if (isCalibrating) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withAlpha(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppLogoLoader(
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colors.primary.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action Trigger Button
        AppButton(
          text: isCalibrating ? 'Calibrating via LLM...' : 'Extract, Calibrate & Generate Deck',
          isLoading: isCalibrating,
          onPressed: isCalibrating ? null : onExecuteCalibration,
          prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18),
        ),
      ],
    );
  }
}
