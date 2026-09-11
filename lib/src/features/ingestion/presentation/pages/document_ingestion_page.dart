import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/camera_scanner_overlay.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone_widget.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/lms_import_modal_sheet.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/synthesis_mode_toggle.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/upload_progress_card.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_document_embeddings_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class DocumentIngestionPage extends StatelessWidget {
  const DocumentIngestionPage({
    this.courseId,
    this.courseCode,
    this.courseTitle,
    super.key,
  });

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IngestionBloc>(
      create: (_) =>
          locator<IngestionBloc>()..add(const FetchUserDocumentsEvent()),
      child: _DocumentIngestionView(
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
      ),
    );
  }
}

class _DocumentIngestionView extends HookWidget {
  const _DocumentIngestionView({
    this.courseId,
    this.courseCode,
    this.courseTitle,
  });

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isScanningCamera = useState<bool>(false);

    if (isScanningCamera.value) {
      return CameraScannerOverlay(
        onImageCaptured: (filename, bytes) {
          isScanningCamera.value = false;
          context.read<IngestionBloc>().add(
            ProcessCameraImageEvent(
              filename: filename,
              imageBytes: bytes,
            ),
          );
        },
        onClose: () => isScanningCamera.value = false,
      );
    }

    return AuraMeshNebula(
      child: Scaffold(
        backgroundColor: colors.transparent,
        appBar: AppBar(
          backgroundColor: colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary,
              size: 20,
            ),
            onPressed: () => unawaited(Navigator.of(context).maybePop()),
          ),
          title: Text(
            l10n.ingestionTitle,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          centerTitle: false,
        ),
        body: BlocConsumer<IngestionBloc, IngestionState>(
          listener: (context, state) {
            if (state.status == ProcessingStatus.completed) {
              if (state.wasDeduplicated &&
                  state.generatedDeck != null &&
                  state.snippets.isEmpty) {
                context.showSnackBar(
                  message: (state.stageMessage != null &&
                          state.stageMessage!.isNotEmpty)
                      ? state.stageMessage!
                      : l10n.dedupExistingDeckAssigned,
                  type: SnackBarType.success,
                );
              } else if (state.snippets.isNotEmpty &&
                  state.currentDocument != null) {
                if (state.wasDeduplicated) {
                  context.showSnackBar(
                    message: l10n.dedupExistingDeckAssigned,
                    type: SnackBarType.success,
                  );
                }

                final doc = state.currentDocument!;
                final rawSubject = doc.filename.split('.').first;
                final cleanCode = rawSubject
                    .replaceAll(RegExp(r'[^a-zA-Z0-9\s_-]'), '')
                    .trim();

                // Background pgvector RAG auto-chunking & embeddings generation
                if (state.snippets.isNotEmpty &&
                    locator.isRegistered<GenerateDocumentEmbeddingsUseCase>()) {
                  unawaited(
                    locator<GenerateDocumentEmbeddingsUseCase>()(
                      documentId: doc.id,
                      snippets: state.snippets,
                      metadata: {
                        'filename': doc.filename,
                        'documentTitle': doc.filename.split('.').first,
                        'courseCode': cleanCode.isNotEmpty
                            ? cleanCode
                            : (courseCode ?? 'GENERAL'),
                        'extractedSnippetsCount': state.snippets.length,
                      },
                    ),
                  );
                }

                // Navigate to STEM OCR Live Preview & Editor
                unawaited(
                  context.router.push(
                    OcrPreviewRoute(
                      documentId: state.currentDocument!.id,
                      filename: state.currentDocument!.filename,
                      snippets: state.snippets,
                      courseId: courseId,
                      courseCode: courseCode,
                      courseTitle: courseTitle,
                    ),
                  ),
                );
              }
            }
          },
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;

                final uploadSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two-Tier Synthesis Mode Toggle (Fast Local vs AI Smart)
                    SynthesisModeToggle(
                      currentMode: state.synthesisMode,
                      onModeSelected: (mode) {
                        context.read<IngestionBloc>().add(
                          SetSynthesisModeEvent(mode),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // File drop zone
                    FileDropZoneWidget(
                      courseId: courseId,
                      courseCode: courseCode,
                      courseTitle: courseTitle,
                      onFilePicked:
                          ({
                            required filename,
                            required fileType,
                            required fileBytes,
                          }) {
                            context.read<IngestionBloc>().add(
                              PickAndUploadFileEvent(
                                filename: filename,
                                fileType: fileType,
                                fileBytes: fileBytes,
                                courseId: courseId,
                                courseCode: courseCode,
                                courseTitle: courseTitle,
                              ),
                            );
                          },
                      onCameraScanTap: () => isScanningCamera.value = true,
                      onLmsImportTap: () =>
                          unawaited(LmsImportModalSheet.show(context)),
                    ),
                    const SizedBox(height: 20),

                    // Progress card if active
                    if (state.status != ProcessingStatus.idle)
                      UploadProgressCard(
                        filename:
                            state.currentDocument?.filename ??
                            'Selected Document',
                        status: state.status,
                        progress: state.uploadProgress,
                        stageMessage: state.stageMessage,
                        wasDeduplicated: state.wasDeduplicated,
                        errorMessage: state.errorMessage,
                        onRetry: () {
                          context.read<IngestionBloc>().add(
                            const ResetIngestionStateEvent(),
                          );
                        },
                      ),
                  ],
                );

                final recentDocsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recently Ingested Documents',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.userDocuments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary.withAlpha(150),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 40 : 20),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No documents ingested yet. '
                            'Upload lecture notes above to start.',
                            textAlign: TextAlign.center,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.userDocuments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = state.userDocuments[index];
                          final kbSize = (doc.fileSizeBytes / 1024)
                              .toStringAsFixed(1);
                          final hasCourseContext =
                              (courseCode != null && courseCode!.isNotEmpty) ||
                              (courseId != null && courseId!.isNotEmpty);
                          final baseName = doc.filename
                              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                              .toLowerCase()
                              .trim();
                          final isAlreadyAttached = hasCourseContext &&
                              (state.attachedDocumentIds.contains(doc.id) ||
                                  (courseCode != null &&
                                      (state.attachedDocumentIds.contains('${doc.id}_$courseCode') ||
                                          state.attachedDocumentIds.contains('${doc.contentHash}_$courseCode') ||
                                          state.attachedDocumentIds.contains('${baseName}_$courseCode'))) ||
                                  (courseId != null &&
                                      (state.attachedDocumentIds.contains('${doc.id}_$courseId') ||
                                          state.attachedDocumentIds.contains('${doc.contentHash}_$courseId') ||
                                          state.attachedDocumentIds.contains('${baseName}_$courseId'))) ||
                                  _checkIsDocAttachedLocally(
                                    doc: doc,
                                    courseId: courseId,
                                    courseCode: courseCode,
                                  ));

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 50 : 25,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: colors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.filename,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: typography.body.bold
                                                .copyWith(
                                                  color: colors.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${doc.fileType.toUpperCase()} • '
                                            '$kbSize KB',
                                            style: typography.caption.medium
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.success.withAlpha(25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Ready',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.success,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasCourseContext) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: isAlreadyAttached
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primary.withAlpha(20),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: colors.primary.withAlpha(60),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  color: colors.primary,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Attached to ${courseCode ?? "Course"}',
                                                  style: typography.caption.bold.copyWith(
                                                    color: colors.primary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              side: BorderSide(
                                                color: colors.primary.withAlpha(80),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () {
                                              context.read<IngestionBloc>().add(
                                                AttachDocumentToCourseEvent(
                                                  doc: doc,
                                                  courseId: courseId,
                                                  courseCode: courseCode,
                                                  courseTitle: courseTitle,
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              Icons.bookmark_add_outlined,
                                              color: colors.primary,
                                              size: 14,
                                            ),
                                            label: Text(
                                              'Attach to ${courseCode ?? "Course"}',
                                              style: typography.caption.bold.copyWith(
                                                color: colors.primary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );

                if (isDesktop) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: uploadSection),
                        const SizedBox(width: 28),
                        Expanded(flex: 4, child: recentDocsSection),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      uploadSection,
                      const SizedBox(height: 28),
                      recentDocsSection,
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _checkIsDocAttachedLocally({
    required DocumentUploadEntity doc,
    required String? courseId,
    required String? courseCode,
  }) {
    final storage = locator.isRegistered<LocalStorageService>()
        ? locator<LocalStorageService>()
        : null;
    if (storage == null) return false;

    final baseName = doc.filename
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .toLowerCase()
        .trim();

    for (final key in [
      'extracted_doc_${doc.contentHash}',
      'extracted_doc_${doc.id}',
      'extracted_doc_$baseName',
    ]) {
      final raw = storage.getPreference(key: key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final cId = map['courseId'] as String?;
          final cCode = map['courseCode'] as String?;
          if (courseId != null && courseId.isNotEmpty && cId == courseId) {
            return true;
          }
          if (courseCode != null &&
              courseCode.isNotEmpty &&
              cCode?.toLowerCase() == courseCode.toLowerCase()) {
            return true;
          }
        } on Object catch (_) {}
      }
    }
    return false;
  }
}
