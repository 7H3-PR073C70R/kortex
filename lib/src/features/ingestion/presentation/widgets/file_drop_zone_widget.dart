import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone/document_already_extracted_dialog.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone/drop_zone_action_buttons.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone/free_daily_uploads_card.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone/ingestion_limit_dialogs.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/l10n/l10n.dart';

export 'file_drop_zone/document_already_extracted_dialog.dart';
export 'file_drop_zone/drop_zone_action_buttons.dart';
export 'file_drop_zone/free_daily_uploads_card.dart';
export 'file_drop_zone/ingestion_limit_dialogs.dart';

/// Primary multi-format document drop and pick target with drag-and-drop support,
/// 50MB/200MB tier limit enforcement, and document deduplication detection.
class FileDropZoneWidget extends HookWidget {
  const FileDropZoneWidget({
    required this.onFilePicked,
    this.onCameraScanTap,
    this.onLmsImportTap,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.subscriptionGuard,
    this.filePickerService,
    this.localStorageService,
    this.decksRepository,
    this.decksBloc,
    this.dashboardBloc,
    super.key,
  });

  final void Function({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
  }) onFilePicked;

  final VoidCallback? onCameraScanTap;
  final VoidCallback? onLmsImportTap;
  final String? courseId;
  final String? courseCode;
  final String? courseTitle;

  final SubscriptionGuard? subscriptionGuard;
  final FilePickerService? filePickerService;
  final LocalStorageService? localStorageService;
  final DecksRepository? decksRepository;
  final DecksBloc? decksBloc;
  final DashboardBloc? dashboardBloc;

  SubscriptionGuard _resolveGuard() =>
      subscriptionGuard ??
      (locator.isRegistered<SubscriptionGuard>()
          ? locator<SubscriptionGuard>()
          : SubscriptionGuard());

  FilePickerService _resolveFilePicker() =>
      filePickerService ??
      (locator.isRegistered<FilePickerService>()
          ? locator<FilePickerService>()
          : FilePickerService());

  LocalStorageService? _resolveStorage() =>
      localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  Map<String, String>? _checkExistingExtractedDeck(
    String filename,
    Uint8List bytes,
  ) {
    try {
      final storage = _resolveStorage();
      if (storage == null) return null;

      final hash = sha256.convert(bytes).toString();
      final baseName = filename
          .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
          .toLowerCase()
          .trim();

      String? deckId;
      String? deckTitle;

      // Check by content hash
      final byHash = storage.getPreference(key: 'extracted_doc_$hash');
      if (byHash != null) {
        try {
          final decoded = jsonDecode(byHash) as Map<String, dynamic>;
          deckId = decoded['deckId'] as String?;
          deckTitle = decoded['deckTitle'] as String?;
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }
      }

      // Check by normalized base filename if not found by hash
      if (deckId == null || deckId.isEmpty) {
        final byName = storage.getPreference(key: 'extracted_doc_$baseName');
        if (byName != null) {
          try {
            final decoded = jsonDecode(byName) as Map<String, dynamic>;
            deckId = decoded['deckId'] as String?;
            deckTitle = decoded['deckTitle'] as String?;
          } on Object catch (e, st) {
            AppLogger.recordNonFatal(e, st);
          }
        }
      }

      if (deckId != null && deckId.isNotEmpty) {
        // Verify deck actually exists if DecksBloc is loaded
        final dBloc = decksBloc ??
            (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null);
        if (dBloc != null) {
          final allDecks = dBloc.state.allDecks;
          if (allDecks.isNotEmpty && !allDecks.any((d) => d.id == deckId)) {
            // Deck was deleted! Purge stale extraction markers
            unawaited(storage.deletePreference(key: 'extracted_doc_$hash'));
            unawaited(storage.deletePreference(key: 'extracted_doc_$baseName'));
            unawaited(storage.deletePreference(key: 'extracted_doc_$deckId'));
            return null;
          }
        }

        return {
          'deckId': deckId,
          'deckTitle':
              deckTitle ?? filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
        };
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
    return null;
  }

  Future<void> _processPickedFileBytes(
    BuildContext context, {
    required String filename,
    required String extension,
    required Uint8List bytes,
  }) async {
    final guard = _resolveGuard();
    final isPro = guard.isPro;

    // 1. File Limit Enforcement (50MB Free, 200MB Pro)
    final maxBytes = isPro
        ? SubscriptionGuard.proMaxSizeBytes
        : SubscriptionGuard.freeMaxSizeBytes;

    if (bytes.lengthInBytes > maxBytes) {
      if (context.mounted) {
        await show50MbUpgradeDialog(
          context,
          filename: filename,
          sizeBytes: bytes.lengthInBytes,
        );
      }
      return;
    }

    // 2. Daily Document Upload Limit (Free: 3/day, Pro: Unlimited)
    if (!isPro &&
        !guard.canUploadDocument(
          fileSizeBytes: bytes.lengthInBytes,
        )) {
      if (context.mounted) {
        await showDailyLimitDialog(context);
      }
      return;
    }

    // 3. Document Deduplication Check
    final existingDeck = _checkExistingExtractedDeck(
      filename,
      bytes,
    );
    if (existingDeck != null && context.mounted) {
      await showAlreadyExtractedDialog(
        context,
        deckTitle: existingDeck['deckTitle']!,
        deckId: existingDeck['deckId']!,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        decksRepository: decksRepository,
        decksBloc: decksBloc,
        dashboardBloc: dashboardBloc,
        onReExtract: () {
          unawaited(guard.recordDocumentUpload());
          onFilePicked(
            filename: filename,
            fileType: extension,
            fileBytes: bytes,
          );
        },
      );
      return;
    }

    unawaited(guard.recordDocumentUpload());

    onFilePicked(
      filename: filename,
      fileType: extension,
      fileBytes: bytes,
    );
  }

  Future<void> _handlePickFile(BuildContext context) async {
    try {
      final filePicker = _resolveFilePicker();
      final doc = await filePicker.pickStudyDocument();

      if (doc != null && doc.bytes.isNotEmpty && context.mounted) {
        await _processPickedFileBytes(
          context,
          filename: doc.name,
          extension: doc.extension,
          bytes: doc.bytes,
        );
      }
    } on Object {
      if (context.mounted) {
        context.showSnackBar(
          message: context.l10n.invalidFileFormatError,
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isHovering = useState<bool>(false);
    final isDragging = useState<bool>(false);
    final guard = _resolveGuard();

    return DropTarget(
      onDragEntered: (_) => isDragging.value = true,
      onDragExited: (_) => isDragging.value = false,
      onDragDone: (details) async {
        isDragging.value = false;
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          final filename = file.name;
          final bytes = await file.readAsBytes();
          final ext = filename.contains('.')
              ? filename.split('.').last.toLowerCase()
              : '';
          if (context.mounted) {
            await _processPickedFileBytes(
              context,
              filename: filename,
              extension: ext,
              bytes: bytes,
            );
          }
        }
      },
      child: Semantics(
        label: !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)
            ? 'Tap to upload PDF, PPTX, DoCX, EPUB, TXT, HTML, MD or image files.'
            : l10n.dragAndDropHint,
        button: true,
        child: GestureDetector(
          onTap: () => _handlePickFile(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => isHovering.value = true,
            onExit: (_) => isHovering.value = false,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: isDragging.value
                    ? colors.primary.withAlpha(isDark ? 50 : 30)
                    : (isHovering.value
                        ? colors.surfaceSecondary
                        : (isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary)),
                borderRadius: AppRadius.radiusDialog,
                border: Border.all(
                  color: (isDragging.value || isHovering.value)
                      ? colors.primary
                      : colors.primary.withAlpha(isDark ? 80 : 40),
                  width: isDragging.value ? 2.5 : 1.5,
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
                      color: colors.primary.withAlpha(isDark ? 30 : 20),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 60 : 40),
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
                    !kIsWeb &&
                            (defaultTargetPlatform == TargetPlatform.android ||
                                defaultTargetPlatform == TargetPlatform.iOS)
                        ? 'Tap to upload PDF, PPTX, DoCX, EPUB, TXT, HTML, MD or image files.'
                        : l10n.dragAndDropHint,
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
                  const SizedBox(height: 12),
                  FreeDailyUploadsCard(subscriptionGuard: guard),
                  const SizedBox(height: 24),

                  // Action Buttons Row
                  DropZoneActionButtons(
                    onPickFile: () => _handlePickFile(context),
                    onCameraScanTap: onCameraScanTap,
                    onLmsImportTap: onLmsImportTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
