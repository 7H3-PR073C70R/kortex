import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class RagReferenceBadge extends StatelessWidget {
  const RagReferenceBadge({
    required this.chunk,
    super.key,
    this.onTap,
  });

  final DocumentChunkEntity chunk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    final colors = context.colors;
    final scorePercent = (chunk.similarityScore * 100).toInt();
    final badgeText = l10n.retrievedContextBadge(scorePercent);
    final title = chunk.documentTitle ?? 'Course Material';
    final citationParts = [
      if (chunk.pageNumber != null) 'p. ${chunk.pageNumber}',
      if (chunk.paragraphNumber != null) 'para. ${chunk.paragraphNumber}',
    ];
    final pageInfo = citationParts.isNotEmpty
        ? ' (${citationParts.join(', ')})'
        : '';

    return Semantics(
      button: true,
      label: '$badgeText: $title$pageInfo',
      hint: 'Tap to inspect source reference snippet',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return Material(
            color: colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.radiusCard,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.snappyCurve,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isHovered
                      ? colors.primary.withAlpha(45)
                      : colors.primary.withAlpha(25),
                  borderRadius: AppRadius.radiusCard,
                  border: Border.all(
                    color: isHovered
                        ? colors.primary.withAlpha(160)
                        : colors.primary.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$title$pageInfo',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.success.withAlpha(40),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                      child: Text(
                        '$scorePercent%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
