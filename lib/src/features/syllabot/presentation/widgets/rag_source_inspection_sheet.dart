import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class RagSourceInspectionSheet extends StatelessWidget {
  const RagSourceInspectionSheet({
    required this.chunk,
    super.key,
  });

  final DocumentChunkEntity chunk;

  static Future<void> show(
    BuildContext context,
    DocumentChunkEntity chunk,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RagSourceInspectionSheet(chunk: chunk),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final scorePercent = (chunk.similarityScore * 100).toInt();
    final title = chunk.documentTitle ?? 'Course Material';

    final citationDetails = [
      if (chunk.pageNumber != null) 'Page ${chunk.pageNumber}',
      if (chunk.paragraphNumber != null) 'Paragraph ${chunk.paragraphNumber}',
    ].join(' • ');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 50 : 30),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Icon + Title + Score Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      if (citationDetails.isNotEmpty)
                        Text(
                          citationDetails,
                          style: typography.caption.medium.copyWith(
                            color: colors.primary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.success.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$scorePercent% Match',
                        style: typography.caption.bold.copyWith(
                          color: colors.success,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content excerpt card
            Text(
              'Retrieved Source Text',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? colors.backgroundSecondary : colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(60),
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  chunk.content,
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons (Copy & Close)
            Row(
              children: [
                Expanded(
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(
                        Clipboard.setData(ClipboardData(text: chunk.content)),
                      );
                      context.showSnackBar(
                        message: 'Source citation copied to clipboard.',
                        type: SnackBarType.success,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Copy Citation',
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShrinkableButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Close',
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
