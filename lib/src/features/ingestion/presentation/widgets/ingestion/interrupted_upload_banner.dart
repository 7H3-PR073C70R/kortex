import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Alert banner displayed when a previous file upload was interrupted before completion.
class InterruptedUploadBanner extends StatelessWidget {
  const InterruptedUploadBanner({
    required this.job,
    required this.onDismiss,
    required this.isDark,
    super.key,
  });

  final Map<String, dynamic> job;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final filename = job['filename'] as String? ?? 'Document';
    final progress =
        ((job['uploadProgress'] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.warning.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.warning.withAlpha(isDark ? 80 : 50),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.warning.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restore_page_rounded,
              color: colors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interrupted Upload Detected',
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$filename was interrupted at ${progress.toStringAsFixed(0)}% uploaded. Please re-select the file to resume.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
