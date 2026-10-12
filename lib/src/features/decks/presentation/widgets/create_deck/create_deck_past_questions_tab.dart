import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/presentation/widgets/upload_past_questions_view.dart';

/// Form tab for uploading and calibrating past question papers into flashcards.
class CreateDeckPastQuestionsTab extends StatelessWidget {
  const CreateDeckPastQuestionsTab({
    required this.pickedFile,
    required this.isCalibrating,
    required this.docStatus,
    required this.onExecuteCalibration,
    super.key,
  });

  final ValueNotifier<PickedDocument?> pickedFile;
  final bool isCalibrating;
  final String docStatus;
  final VoidCallback onExecuteCalibration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(120)
            : colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: UploadPastQuestionsView(
        pickedFile: pickedFile,
        isCalibrating: isCalibrating,
        statusText: docStatus.isNotEmpty
            ? docStatus
            : 'Calibrating past question asset...',
        progress: isCalibrating ? 0.65 : 0.0,
        onExecuteCalibration: onExecuteCalibration,
      ),
    );
  }
}
