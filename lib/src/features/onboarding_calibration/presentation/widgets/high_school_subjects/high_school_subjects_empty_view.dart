import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Empty state rendered when search query yields no matching subjects.
class HighSchoolSubjectsEmptyView extends StatelessWidget {
  const HighSchoolSubjectsEmptyView({
    required this.searchQuery,
    required this.onReset,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(60)
            : colors.surfacePrimary.withAlpha(150),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(40)
              : colors.surfaceBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 36,
            color: colors.textSecondary.withAlpha(140),
          ),
          const SizedBox(height: 10),
          Text(
            'No subjects found matching "$searchQuery"',
            textAlign: TextAlign.center,
            style: typography.subhead.medium.copyWith(
              color: colors.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onReset,
            child: Text(
              'Reset search & filters',
              style: typography.caption.bold.copyWith(
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
