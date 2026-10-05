import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Item descriptor for an individual breadcrumb link or label.
class AppBreadcrumbItem {
  const AppBreadcrumbItem({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
}

/// A desktop and web adaptive breadcrumb navigation widget.
///
/// Features:
/// - Semantic accessibility labeling
/// - Platform hover states and light haptic feedback
/// - Subtle visual separation with directional chevrons
/// - Truncation protection for long titles
class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({
    required this.items,
    super.key,
  });

  final List<AppBreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Breadcrumb navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colors.textSecondary.withAlpha(140),
                  ),
                ),
              _BreadcrumbNode(
                item: items[i],
                isCurrent: i == items.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbNode extends StatelessWidget {
  const _BreadcrumbNode({
    required this.item,
    required this.isCurrent,
  });

  final AppBreadcrumbItem item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    if (isCurrent || item.onTap == null) {
      return Text(
        item.label,
        style: typography.subhead.semiBold.copyWith(
          color: colors.textPrimary,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            item.onTap!();
          },
          shrinkScale: 0.98,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.badge),
              color: isHovered
                  ? colors.surfaceBorder.withAlpha(40)
                  : colors.transparent,
            ),
            child: Text(
              item.label,
              style: typography.subhead.regular.copyWith(
                color: isHovered ? colors.primary : colors.textSecondary,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
