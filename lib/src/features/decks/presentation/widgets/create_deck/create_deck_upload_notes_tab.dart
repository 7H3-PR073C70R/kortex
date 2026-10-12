import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Form tab for selecting and extracting flashcards from lecture documents.
class CreateDeckUploadNotesTab extends StatelessWidget {
  const CreateDeckUploadNotesTab({
    required this.pickedDoc,
    required this.isIngesting,
    required this.docStatus,
    required this.onPickDocument,
    required this.onExtractCards,
    super.key,
  });

  final PickedDocument? pickedDoc;
  final bool isIngesting;
  final String docStatus;
  final VoidCallback onPickDocument;
  final VoidCallback onExtractCards;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Lecture Notes / Slides',
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Extracts notes from PDF, PPTX, or TXT documents and synthesizes flashcards for this deck.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ShrinkableButton(
            onTap: isIngesting ? null : onPickDocument,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 24,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceTertiary.withAlpha(60)
                    : colors.surfaceSecondary.withAlpha(60),
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: pickedDoc != null
                      ? colors.primary
                      : colors.surfaceBorder,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    pickedDoc != null
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 32,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pickedDoc?.name ?? 'Select PDF, PPTX or Text Document',
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (isIngesting) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                AppLogoLoader(
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  docStatus,
                  style: typography.caption.regular.copyWith(
                    color: colors.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: isIngesting ? 'Processing...' : 'Extract Flashcards',
              isLoading: isIngesting,
              onPressed: isIngesting || pickedDoc == null ? null : onExtractCards,
            ),
          ),
        ],
      ),
    );
  }
}
