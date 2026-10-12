import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/camera_scanner_overlay.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/document_upload_control_section.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/recent_documents_section.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_document_embeddings_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

@RoutePage()
class DocumentIngestionPage extends StatelessWidget {
  DocumentIngestionPage({
    this.courseId,
    this.courseCode,
    this.courseTitle,
    IngestionBloc? ingestionBloc,
    SubscriptionGuard? subscriptionGuard,
    GenerateDocumentEmbeddingsUseCase? generateDocumentEmbeddingsUseCase,
    LocalStorageService? localStorageService,
    super.key,
  })  : _ingestionBloc = ingestionBloc ??
            (locator.isRegistered<IngestionBloc>()
                ? locator<IngestionBloc>()
                : null),
        _subscriptionGuard = subscriptionGuard ??
            (locator.isRegistered<SubscriptionGuard>()
                ? locator<SubscriptionGuard>()
                : SubscriptionGuard()),
        _generateDocumentEmbeddingsUseCase =
            generateDocumentEmbeddingsUseCase ??
                (locator.isRegistered<GenerateDocumentEmbeddingsUseCase>()
                    ? locator<GenerateDocumentEmbeddingsUseCase>()
                    : null),
        _localStorageService = localStorageService ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null);

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final IngestionBloc? _ingestionBloc;
  final SubscriptionGuard _subscriptionGuard;
  final GenerateDocumentEmbeddingsUseCase? _generateDocumentEmbeddingsUseCase;
  final LocalStorageService? _localStorageService;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc = _ingestionBloc ?? locator<IngestionBloc>();

    return BlocProvider<IngestionBloc>.value(
      value: effectiveBloc
        ..add(const FetchUserDocumentsEvent())
        ..add(const CheckPendingIngestionJobEvent()),
      child: _DocumentIngestionView(
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        subscriptionGuard: _subscriptionGuard,
        generateDocumentEmbeddingsUseCase: _generateDocumentEmbeddingsUseCase,
        localStorageService: _localStorageService,
      ),
    );
  }
}

class _DocumentIngestionView extends HookWidget {
  const _DocumentIngestionView({
    required this.subscriptionGuard,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.generateDocumentEmbeddingsUseCase,
    this.localStorageService,
  });

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final SubscriptionGuard subscriptionGuard;
  final GenerateDocumentEmbeddingsUseCase? generateDocumentEmbeddingsUseCase;
  final LocalStorageService? localStorageService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final remainingQuota = useState<int>(
      subscriptionGuard.getRemainingAiSmartGenCount(),
    );

    useEffect(() {
      unawaited(
        subscriptionGuard.fetchAiSmartGenQuota().then((_) {
          remainingQuota.value =
              subscriptionGuard.getRemainingAiSmartGenCount();
        }),
      );
      return null;
    }, const []);

    final isScanningCamera = useState<bool>(false);

    if (isScanningCamera.value) {
      return CameraScannerOverlay(
        onImagesCaptured: (images) {
          isScanningCamera.value = false;
          if (images.isNotEmpty) {
            context.read<IngestionBloc>().add(
                  ProcessCameraImagesEvent(images: images),
                );
          }
        },
        onClose: () => isScanningCamera.value = false,
      );
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: BlocConsumer<IngestionBloc, IngestionState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == ProcessingStatus.completed,
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
              context.read<IngestionBloc>().add(
                    const ResetIngestionStateEvent(),
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
              final snippets = List<OcrExtractionEntity>.from(state.snippets);
              final rawSubject = doc.filename.split('.').first;
              final cleanCode = rawSubject
                  .replaceAll(RegExp(r'[^a-zA-Z0-9\s_-]'), '')
                  .trim();

              // Reset BLoC state so tab switching or reloads won't re-trigger navigation
              context.read<IngestionBloc>().add(
                    const ResetIngestionStateEvent(),
                  );

              // Background pgvector RAG auto-chunking & embeddings generation
              if (snippets.isNotEmpty &&
                  generateDocumentEmbeddingsUseCase != null) {
                unawaited(
                  generateDocumentEmbeddingsUseCase!(
                    documentId: doc.id,
                    snippets: snippets,
                    metadata: {
                      'filename': doc.filename,
                      'documentTitle': doc.filename.split('.').first,
                      'courseCode': cleanCode.isNotEmpty
                          ? cleanCode
                          : (courseCode ?? 'GENERAL'),
                      'extractedSnippetsCount': snippets.length,
                    },
                  ),
                );
              }

              // Navigate to STEM OCR Live Preview & Editor
              unawaited(
                context.router.push(
                  OcrPreviewRoute(
                    documentId: doc.id,
                    filename: doc.filename,
                    snippets: snippets,
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
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: colors.transparent,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                leading: AppBackButton.adaptiveLeading(context),
                leadingWidth: AppBackButton.shouldShow(context) ? null : 0,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: colors.backgroundPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                title: AppBackButton.shouldShow(context)
                    ? Text(
                        l10n.ingestionTitle,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      )
                    : AppBreadcrumbs(
                        items: [
                          AppBreadcrumbItem(
                            label: 'Dashboard',
                            onTap: () => context.router.maybePop(),
                          ),
                          AppBreadcrumbItem(label: l10n.ingestionTitle),
                        ],
                      ),
                centerTitle: false,
              ),
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 1024;

                    final uploadSection = DocumentUploadControlSection(
                      state: state,
                      guard: subscriptionGuard,
                      remainingQuota: remainingQuota.value,
                      onUpdateQuota: (quota) => remainingQuota.value = quota,
                      onModeSelected: (mode) {
                        context.read<IngestionBloc>().add(
                              SetSynthesisModeEvent(mode),
                            );
                      },
                      onFilePicked: ({
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
                      onDismissPendingJob: () {
                        context.read<IngestionBloc>().add(
                              const DismissPendingIngestionJobEvent(),
                            );
                      },
                      onRetryProgress: () {
                        context.read<IngestionBloc>().add(
                              const ResetIngestionStateEvent(),
                            );
                      },
                      isDark: isDark,
                      courseId: courseId,
                      courseCode: courseCode,
                      courseTitle: courseTitle,
                    );

                    final recentDocsSection = RecentDocumentsSection(
                      userDocuments: state.userDocuments,
                      attachedDocumentIds: state.attachedDocumentIds,
                      courseId: courseId,
                      courseCode: courseCode,
                      courseTitle: courseTitle,
                      isDark: isDark,
                      localStorageService: localStorageService,
                      onAttachDocument: (doc) {
                        context.read<IngestionBloc>().add(
                              AttachDocumentToCourseEvent(
                                doc: doc,
                                courseId: courseId,
                                courseCode: courseCode,
                                courseTitle: courseTitle,
                              ),
                            );
                      },
                      onDeleteDocument: (doc) {
                        context.read<IngestionBloc>().add(
                              DeleteUserDocumentEvent(doc.id),
                            );
                      },
                    );

                    if (isDesktop) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: uploadSection),
                                const SizedBox(width: 28),
                                Expanded(flex: 4, child: recentDocsSection),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              uploadSection,
                              const SizedBox(height: 28),
                              recentDocsSection,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
