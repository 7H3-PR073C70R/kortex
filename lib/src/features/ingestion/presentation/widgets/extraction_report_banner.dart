import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';

/// A transparency banner displaying the extraction report audit summary,
/// notifying users when front-matter was skipped, OCR fallback was applied,
/// or noise/marginalia lines were filtered.
class ExtractionReportBanner extends StatelessWidget {
  const ExtractionReportBanner({
    required this.report,
    super.key,
  });

  final ExtractionReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final droppedCount = report.totalDroppedElements;
    final isScanned = report.isScanned;
    final warningsCount = report.warnings.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: isScanned
              ? colors.warning.withAlpha(isDark ? 90 : 50)
              : colors.primary.withAlpha(isDark ? 80 : 40),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isScanned ? Icons.scanner_rounded : Icons.auto_awesome_rounded,
                  size: 18,
                  color: isScanned ? colors.warning : colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isScanned
                        ? 'Scanned Document (OCR Engine Applied)'
                        : 'Source Extraction & Transparency Audit',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (droppedCount > 0 || warningsCount > 0)
                  InkWell(
                    borderRadius: AppRadius.radiusMicro,
                    onTap: () => _showAuditLogSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Inspect Audit',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(40)
                : colors.surfaceBorder.withAlpha(80),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Lines retained pill
                _AuditPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: '${report.totalLinesRetained} lines retained',
                  color: colors.success,
                ),

                // Front matter or boilerplate filtered pill
                if (droppedCount > 0)
                  _AuditPill(
                    icon: Icons.filter_alt_outlined,
                    label: '$droppedCount boilerplate / front-matter items filtered',
                    color: colors.textSecondary,
                  ),

                // OCR fallback pill
                if (isScanned)
                  _AuditPill(
                    icon: Icons.visibility_outlined,
                    label: 'Optical Character Recognition fallback active',
                    color: colors.warning,
                  ),

                // Warnings pill
                if (warningsCount > 0)
                  _AuditPill(
                    icon: Icons.info_outline_rounded,
                    label: '$warningsCount notices',
                    color: colors.warning,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAuditLogSheet(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? colors.surfacePrimary : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.4,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withAlpha(60),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Extraction Transparency Audit Log',
                          style: typography.title3.bold.copyWith(
                            fontSize: 16,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Audit records of dropped elements, skipped front-matter, and marginalia filters.',
                      style: typography.caption.regular.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: report.droppedElements.length,
                        separatorBuilder: (_, index) => const Divider(height: 12),
                        itemBuilder: (context, i) {
                          final item = report.droppedElements[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.textSecondary.withAlpha(20),
                                borderRadius: AppRadius.radiusMicro,
                              ),
                              child: Icon(Icons.remove_circle_outline, size: 16, color: colors.textSecondary),
                            ),
                            title: Text(
                              'Rule: ${item.rule}${item.page != null ? " (p. ${item.page})" : ""}',
                              style: typography.footnote.bold,
                            ),
                            subtitle: Text(
                              item.sampleText,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AuditPill extends StatelessWidget {
  const _AuditPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 15),
        borderRadius: AppRadius.radiusMicro,
        border: Border.all(color: color.withAlpha(isDark ? 70 : 35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
