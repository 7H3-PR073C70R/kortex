import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/recent_document_card.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Section listing recently ingested documents, allowing attachment to courses or deletion.
class RecentDocumentsSection extends StatelessWidget {
  const RecentDocumentsSection({
    required this.userDocuments,
    required this.attachedDocumentIds,
    required this.onAttachDocument,
    required this.onDeleteDocument,
    required this.isDark,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.localStorageService,
    super.key,
  });

  final List<DocumentUploadEntity> userDocuments;
  final Set<String> attachedDocumentIds;
  final void Function(DocumentUploadEntity doc) onAttachDocument;
  final void Function(DocumentUploadEntity doc) onDeleteDocument;
  final bool isDark;
  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final LocalStorageService? localStorageService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final hasCourseContext =
        (courseCode != null && courseCode!.isNotEmpty) ||
        (courseId != null && courseId!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            'RECENTLY INGESTED DOCUMENTS',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary.withAlpha(170),
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (userDocuments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
              ),
            ),
            child: Center(
              child: Text(
                'No documents ingested yet. Upload lecture notes above to start.',
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
            itemCount: userDocuments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = userDocuments[index];
              final baseName = doc.filename
                  .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                  .toLowerCase()
                  .trim();

              final isAlreadyAttached =
                  hasCourseContext &&
                  (attachedDocumentIds.contains(doc.id) ||
                      (courseCode != null &&
                          (attachedDocumentIds.contains('${doc.id}_$courseCode') ||
                              attachedDocumentIds.contains('${doc.contentHash}_$courseCode') ||
                              attachedDocumentIds.contains('${baseName}_$courseCode'))) ||
                      (courseId != null &&
                          (attachedDocumentIds.contains('${doc.id}_$courseId') ||
                              attachedDocumentIds.contains('${doc.contentHash}_$courseId') ||
                              attachedDocumentIds.contains('${baseName}_$courseId'))) ||
                      _checkIsDocAttachedLocally(doc: doc));

              return RecentDocumentCard(
                doc: doc,
                isAlreadyAttached: isAlreadyAttached,
                hasCourseContext: hasCourseContext,
                courseCode: courseCode,
                isDark: isDark,
                onDelete: () => _confirmDeleteDocument(context: context, doc: doc),
                onAttach: () => onAttachDocument(doc),
              );
            },
          ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 150.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  bool _checkIsDocAttachedLocally({required DocumentUploadEntity doc}) {
    if (localStorageService == null) return false;

    final baseName = doc.filename
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .toLowerCase()
        .trim();

    for (final key in [
      'extracted_doc_${doc.contentHash}',
      'extracted_doc_${doc.id}',
      'extracted_doc_$baseName',
    ]) {
      final raw = localStorageService!.getPreference(key: key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final cId = map['courseId'] as String?;
          final cCode = map['courseCode'] as String?;
          if (courseId != null && courseId!.isNotEmpty && cId == courseId) {
            return true;
          }
          if (courseCode != null &&
              courseCode!.isNotEmpty &&
              cCode?.toLowerCase() == courseCode!.toLowerCase()) {
            return true;
          }
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }
      }
    }
    return false;
  }

  Future<void> _confirmDeleteDocument({
    required BuildContext context,
    required DocumentUploadEntity doc,
  }) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDarkMode
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Document?',
          style: typography.headline.bold.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${doc.filename}" from recently ingested documents?',
          style: typography.body.regular.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: typography.body.bold.copyWith(color: colors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      onDeleteDocument(doc);
      context.showSnackBar(
        message: '"${doc.filename}" removed from ingested documents.',
        type: SnackBarType.success,
      );
    }
  }
}
