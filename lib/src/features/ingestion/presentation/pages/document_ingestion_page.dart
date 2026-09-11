import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
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
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
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
                                      if (courseCode != null &&
                                          courseCode!.isNotEmpty) {
                                        context.read<IngestionBloc>().add(
                                          AttachDocumentToCourseEvent(
                                            doc: doc,
                                            courseId: courseId,
                                            courseCode: courseCode,
                                            courseTitle: courseTitle,
                                          ),
                                        );
                                      } else {
                                        unawaited(
                                          _showCourseAttachmentSheet(
                                            context: context,
                                            doc: doc,
                                          ),
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      Icons.bookmark_add_outlined,
                                      color: colors.primary,
                                      size: 14,
                                    ),
                                    label: Text(
                                      courseCode != null &&
                                              courseCode!.isNotEmpty
                                          ? 'Attach to $courseCode'
                                          : 'Attach Deck',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
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

  Future<void> _showCourseAttachmentSheet({
    required BuildContext context,
    required DocumentUploadEntity doc,
  }) async {
    final storage = locator.isRegistered<LocalStorageService>()
        ? locator<LocalStorageService>()
        : null;
    var courses = <CuratedCourseModel>[];
    try {
      final raw = storage?.getPreference(key: PrefKeys.userCuratedCourses);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        courses = list
            .whereType<Map<String, dynamic>>()
            .map(CuratedCourseModel.fromJson)
            .toList();
      }
    } on Object catch (_) {}

    if (courses.isEmpty) {
      context.read<IngestionBloc>().add(
        AttachDocumentToCourseEvent(
          doc: doc,
          courseCode: 'GENERAL',
          courseTitle: 'General Studies',
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        final mColors = modalCtx.colors;
        final mTypo = modalCtx.typography;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: mColors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Attach Study Deck to Course',
                  style: mTypo.title3.bold.copyWith(color: mColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select an enrolled course for "${doc.filename}":',
                  style: mTypo.caption.regular.copyWith(
                    color: mColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: courses.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final c = courses[idx];
                      return InkWell(
                        onTap: () {
                          Navigator.of(modalCtx).pop();
                          context.read<IngestionBloc>().add(
                            AttachDocumentToCourseEvent(
                              doc: doc,
                              courseId: c.id,
                              courseCode: c.courseCode,
                              courseTitle: c.title,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: mColors.surfaceSecondary.withAlpha(120),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: mColors.primary.withAlpha(30),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: mColors.primary.withAlpha(30),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.school_rounded,
                                  color: mColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.courseCode,
                                      style: mTypo.body.bold.copyWith(
                                        color: mColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      c.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: mTypo.caption.regular.copyWith(
                                        color: mColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: mColors.textSecondary,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
