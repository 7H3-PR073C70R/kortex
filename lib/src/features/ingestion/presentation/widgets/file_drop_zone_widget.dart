import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/presentation/screens/paywall_screen.dart';
import 'package:kortex/src/l10n/l10n.dart';
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
  })
  onFilePicked;

  final VoidCallback? onCameraScanTap;

  Map<String, String>? _checkExistingExtractedDeck(
    String filename,
    Uint8List bytes,
  ) {
    try {
      final storage = locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null;
      if (storage == null) return null;

      final hash = sha256.convert(bytes).toString();

      // Check by content hash
      final byHash = storage.getPreference(key: 'extracted_doc_$hash');
      if (byHash != null) {
        final decoded = jsonDecode(byHash) as Map<String, dynamic>;
        return {
          'deckId': decoded['deckId'] as String? ?? 'deck_${hash.substring(0, 8)}',
          'deckTitle':
              decoded['deckTitle'] as String? ??
              filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
        };
      }

      // Check by normalized base filename
      final baseName = filename
          .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
          .toLowerCase()
          .trim();
      final byName = storage.getPreference(key: 'extracted_doc_$baseName');
      if (byName != null) {
        final decoded = jsonDecode(byName) as Map<String, dynamic>;
        return {
          'deckId': decoded['deckId'] as String? ?? '',
          'deckTitle': decoded['deckTitle'] as String? ?? baseName,
        };
      }
    } on Object catch (_) {}
    return null;
  }

  Future<void> _show50MbUpgradeDialog(
    BuildContext context,
    String filename,
    int sizeBytes,
  ) async {
    final colors = context.colors;
    final typography = context.typography;
    final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.primary.withAlpha(60)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.error.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file_rounded,
                color: colors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '50MB Limit Exceeded',
                style: typography.title3.bold.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'The selected file "$filename" is $sizeMb MB, which exceeds the 50MB free tier limit.\n\nUpgrade to Kortex Pro to upload documents up to 200MB with unlimited AI flashcard synthesis.',
          style: typography.callout.regular.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Dismiss',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Upgrade Tier'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAlreadyExtractedDialog(
    BuildContext context, {
    required String deckTitle,
    required String deckId,
    required VoidCallback onReExtract,
  }) async {
    final colors = context.colors;
    final typography = context.typography;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.primary.withAlpha(60)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.style_rounded,
                color: colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Document Already Extracted',
                style: typography.title3.bold.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'We previously extracted this document as "$deckTitle".\n\nWould you like to open the existing study deck or re-extract it from scratch?',
          style: typography.callout.regular.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: colors.surfaceBorder),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onReExtract();
            },
            child: const Text('Re-extract'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              unawaited(
                context.router.push(StudySessionRoute(deckId: deckId)),
              );
            },
            child: Text('Open "$deckTitle"'),
          ),
        ],
      ),
    );
  }

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
          // 1. 50MB Limit Enforcement (Item 9)
          if (doc.bytes.lengthInBytes > 50 * 1024 * 1024) {
            if (context.mounted) {
              await _show50MbUpgradeDialog(
                context,
                doc.name,
                doc.bytes.lengthInBytes,
              );
            }
            return;
          }

          // 2. Document Deduplication Check (Item 7)
          final existingDeck = _checkExistingExtractedDeck(
            doc.name,
            doc.bytes,
          );
          if (existingDeck != null && context.mounted) {
            await _showAlreadyExtractedDialog(
              context,
              deckTitle: existingDeck['deckTitle']!,
              deckId: existingDeck['deckId']!,
              onReExtract: () {
                onFilePicked(
                  filename: doc.name,
                  fileType: doc.extension,
                  fileBytes: doc.bytes,
                );
              },
            );
            return;
          }

          onFilePicked(
            filename: doc.name,
            fileType: doc.extension,
            fileBytes: doc.bytes,
          );
        }
      } on Object {
        if (context.mounted) {
          context.showSnackBar(
            message: l10n.invalidFileFormatError,
            type: SnackBarType.error,
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
