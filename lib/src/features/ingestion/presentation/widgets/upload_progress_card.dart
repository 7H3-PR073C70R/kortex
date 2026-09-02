import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class UploadProgressCard extends HookWidget {
  const UploadProgressCard({
    required this.filename,
    required this.status,
    required this.progress,
    this.wasDeduplicated = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final String filename;
  final ProcessingStatus status;
  final double progress;
  final bool wasDeduplicated;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isCompleted = status == ProcessingStatus.completed;
    final isFailed = status == ProcessingStatus.failed;

    String statusText;
    if (isFailed) {
      statusText = errorMessage ?? 'Processing failed';
    } else if (wasDeduplicated) {
      statusText = l10n.contentAlreadyUploadedNotice;
    } else {
      switch (status) {
        case ProcessingStatus.uploading:
          statusText = l10n.uploadingStatus;
        case ProcessingStatus.parsingOcr:
          statusText = l10n.processingOcrStatus;
        case ProcessingStatus.generatingCards:
          statusText = l10n.generatingCardsStatus;
        case ProcessingStatus.completed:
          statusText = 'Document extraction ready';
        case ProcessingStatus.idle:
        case ProcessingStatus.failed:
          statusText = '';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFailed
              ? colors.error.withAlpha(120)
              : (isCompleted
                  ? colors.success.withAlpha(100)
                  : colors.primary.withAlpha(isDark ? 80 : 40)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Filename + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFailed
                      ? colors.error.withAlpha(30)
                      : (isCompleted
                          ? colors.success.withAlpha(30)
                          : colors.primary.withAlpha(30)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFailed
                      ? Icons.error_outline_rounded
                      : (isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.insert_drive_file_outlined),
                  color: isFailed
                      ? colors.error
                      : (isCompleted ? colors.success : colors.primary),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: typography.caption.medium.copyWith(
                        color: isFailed
                            ? colors.error
                            : (isCompleted
                                ? colors.success
                                : colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (isFailed && onRetry != null)
                ShrinkableButton(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: colors.error,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),

          if (!isCompleted && !isFailed) ...[
            const SizedBox(height: 16),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: status == ProcessingStatus.parsingOcr ? null : progress,
                backgroundColor: colors.primary.withAlpha(isDark ? 40 : 20),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
