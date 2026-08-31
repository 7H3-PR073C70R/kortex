import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/services/file_picker_service.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class FileDropZoneWidget extends HookWidget {
  const FileDropZoneWidget({
    required this.onFilePicked,
    this.onCameraScanTap,
    super.key,
  });

  final void Function({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
  }) onFilePicked;

  final VoidCallback? onCameraScanTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isHovering = useState<bool>(false);

    Future<void> handlePickFile() async {
      unawaited(HapticFeedback.lightImpact());
      try {
        final filePickerService = locator.isRegistered<FilePickerService>()
            ? locator<FilePickerService>()
            : FilePickerService();

        final doc = await filePickerService.pickStudyDocument();

        if (doc != null && doc.bytes.isNotEmpty) {
          onFilePicked(
            filename: doc.name,
            fileType: doc.extension,
            fileBytes: doc.bytes,
          );
        }
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.invalidFileFormatError),
              backgroundColor: colors.error,
            ),
          );
        }
      }
    }

    return Semantics(
      label: l10n.dragAndDropHint,
      button: true,
      child: MouseRegion(
        onEnter: (_) => isHovering.value = true,
        onExit: (_) => isHovering.value = false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: isDark
                ? (isHovering.value
                    ? colors.primary.withAlpha(30)
                    : colors.surfaceSecondary.withAlpha(160))
                : (isHovering.value
                    ? colors.primary.withAlpha(20)
                    : colors.surfacePrimary.withAlpha(200)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHovering.value
                  ? colors.primary
                  : colors.primary.withAlpha(isDark ? 80 : 50),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with pulsating gradient glow
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 80 : 40),
                      colors.syllabotAccent.withAlpha(isDark ? 60 : 30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 34,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title & Hint
              Text(
                l10n.dragAndDropHint,
                textAlign: TextAlign.center,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.supportedFormatsNotice,
                textAlign: TextAlign.center,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons Row
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  // Browse Files Button
                  ShrinkableButton(
                    onTap: handlePickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withAlpha(210),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(isDark ? 80 : 40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.folder_open_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.browseFilesButton,
                            style: typography.footnote.bold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Camera Scanner Button
                  if (onCameraScanTap != null)
                    ShrinkableButton(
                      onTap: onCameraScanTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 90 : 60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: colors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.cameraCaptureButton,
                              style: typography.footnote.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
