import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Clean card container with uppercase header and explanatory subtitle.
class SecuritySectionContainer extends StatelessWidget {
  const SecuritySectionContainer({
    required this.title,
    required this.child,
    this.subtitle = '',
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: typography.headline.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary.withAlpha(200),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(80),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}
