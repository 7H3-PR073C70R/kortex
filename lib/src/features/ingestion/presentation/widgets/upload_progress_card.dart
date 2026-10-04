import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class UploadProgressCard extends HookWidget {
  const UploadProgressCard({
    required this.filename,
    required this.status,
    required this.progress,
    this.stageMessage,
    this.wasDeduplicated = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final String filename;
  final ProcessingStatus status;
  final double progress;
  final String? stageMessage;
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

    // Guaranteed clamped progressive percentage [0.05, 1.0]
    final effectiveProgress = isCompleted
        ? 1.0
        : (isFailed ? 0.0 : progress.clamp(0.05, 1.0));

    String statusText;
    if (isFailed) {
      statusText = errorMessage ?? 'Processing failed';
    } else if (stageMessage != null && stageMessage!.isNotEmpty) {
      statusText = stageMessage!;
    } else if (wasDeduplicated) {
      statusText = l10n.contentAlreadyUploadedNotice;
    } else {
      switch (status) {
        case ProcessingStatus.uploading:
          statusText = l10n.uploadingStatus;
        case ProcessingStatus.parsingOcr:
          statusText = l10n.readingDocumentLocallyStatus;
        case ProcessingStatus.generatingCards:
          statusText = l10n.structuringFlashcardsStatus;
        case ProcessingStatus.syncingDb:
          statusText = l10n.syncingToSupabaseStatus;
        case ProcessingStatus.completed:
          statusText = l10n.documentExtractionReady;
        case ProcessingStatus.idle:
        case ProcessingStatus.failed:
          statusText = '';
      }
    }

    final stageBadge = switch (status) {
      ProcessingStatus.uploading => 'Uploading',
      ProcessingStatus.parsingOcr => 'Extracting',
      ProcessingStatus.generatingCards => 'Luna AI',
      ProcessingStatus.syncingDb => 'Syncing',
      ProcessingStatus.completed => 'Completed',
      ProcessingStatus.failed => 'Failed',
      ProcessingStatus.idle => 'Queued',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: isFailed
              ? colors.error.withAlpha(120)
              : (isCompleted
                  ? colors.success.withAlpha(100)
                  : colors.primary.withAlpha(isDark ? 80 : 40)),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 25 : 10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Filename + Status Badge + Retry
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFailed
                      ? colors.error.withAlpha(30)
                      : (isCompleted
                          ? colors.success.withAlpha(30)
                          : colors.primary.withAlpha(30)),
                  borderRadius: AppRadius.radiusCard,
                ),
                child: Icon(
                  isFailed
                      ? Icons.error_outline_rounded
                      : (isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.auto_awesome_rounded),
                  color: isFailed
                      ? colors.error
                      : (isCompleted ? colors.success : colors.primary),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isFailed
                                ? colors.error.withAlpha(25)
                                : (isCompleted
                                    ? colors.success.withAlpha(25)
                                    : colors.primary.withAlpha(25)),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            stageBadge,
                            style: typography.caption.bold.copyWith(
                              color: isFailed
                                  ? colors.error
                                  : (isCompleted
                                      ? colors.success
                                      : colors.primary),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
              if (isFailed && onRetry != null) ...[
                const SizedBox(width: 10),
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return AnimatedScale(
                      scale: isHovered ? 1.08 : 1.0,
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      child: child,
                    );
                  },
                  child: ShrinkableButton(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(25),
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: colors.error,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (!isFailed) ...[
            const SizedBox(height: 18),
            // Progressive Percentage Bar with live % badge
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.05,
                end: effectiveProgress,
              ),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                final percentInt = (animatedValue * 100).toInt().clamp(5, 100);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isCompleted
                              ? '100% COMPLETE'
                              : 'SYNTHESIS IN PROGRESS',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary.withAlpha(180),
                            letterSpacing: 0.6,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          isCompleted ? '100%' : '$percentInt%',
                          style: typography.caption.bold.copyWith(
                            color: isCompleted
                                ? colors.success
                                : colors.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: AppRadius.radiusMicro,
                      child: SizedBox(
                        height: 7,
                        child: LinearProgressIndicator(
                          value: isCompleted ? 1.0 : animatedValue,
                          backgroundColor:
                              colors.primary.withAlpha(isDark ? 40 : 20),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? colors.success : colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
