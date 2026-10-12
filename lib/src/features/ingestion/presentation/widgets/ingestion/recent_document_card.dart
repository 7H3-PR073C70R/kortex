import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Card tile presenting a single ingested document with file metadata,
/// course attachment action/status, and deletion control.
class RecentDocumentCard extends StatelessWidget {
  const RecentDocumentCard({
    required this.doc,
    required this.isAlreadyAttached,
    required this.hasCourseContext,
    required this.onDelete,
    required this.onAttach,
    required this.isDark,
    this.courseCode,
    super.key,
  });

  final DocumentUploadEntity doc;
  final bool isAlreadyAttached;
  final bool hasCourseContext;
  final VoidCallback onDelete;
  final VoidCallback onAttach;
  final bool isDark;
  final String? courseCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final kbSize = (doc.fileSizeBytes / 1024).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 25),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.fileType.toUpperCase()} • $kbSize KB',
                      style: typography.caption.medium.copyWith(
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
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  'Ready',
                  style: typography.caption.bold.copyWith(
                    color: colors.success,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedScale(
                    scale: isHovered ? 1.12 : 1.0,
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    child: child,
                  );
                },
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.textSecondary.withAlpha(180),
                    size: 20,
                  ),
                  tooltip: 'Delete Document',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onDelete,
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
                        borderRadius: AppRadius.radiusBadge,
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
                  : PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedScale(
                          scale: isHovered ? 1.03 : 1.0,
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          child: child,
                        );
                      },
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
                            borderRadius: AppRadius.radiusBadge,
                          ),
                        ),
                        onPressed: onAttach,
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
            ),
          ],
        ],
      ),
    );
  }
}
