import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

/// Adaptive top navigation bar for the forum thread detail screen.
///
/// Features hierarchical breadcrumbs, subscription notification toggling,
/// content flagging, sharing, and an optional close button for split-pane views.
class ForumThreadDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ForumThreadDetailAppBar({
    required this.postTitle,
    required this.isSubscribed,
    required this.onToggleSubscription,
    required this.onReport,
    required this.onShare,
    this.onClosePanel,
    super.key,
  });

  final String postTitle;
  final bool isSubscribed;
  final VoidCallback onToggleSubscription;
  final VoidCallback onReport;
  final VoidCallback onShare;
  final VoidCallback? onClosePanel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return AppAdaptiveAppBar(
      backgroundColor:
          (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
              .withAlpha(230),
      breadcrumbs: [
        AppBreadcrumbItem(
          label: 'Community',
          onTap: () {
            if (context.router.canPop()) {
              context.router.pop();
            }
          },
        ),
        AppBreadcrumbItem(label: postTitle),
      ],
      title: Text(
        'Thread Detail',
        style: typography.title3.bold.copyWith(
          color: colors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        // 1. Notification Toggle Button (Bell with real-time active status dot)
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                isSubscribed
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color:
                    isSubscribed ? colors.primary : colors.textSecondary,
                size: 22,
              ),
              tooltip: isSubscribed
                  ? 'Mute Notifications'
                  : 'Turn on Notifications',
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                onToggleSubscription();
              },
            ),
            if (isSubscribed)
              Positioned(
                top: 11,
                right: 12,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                    border: Border.all(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // 2. Report / Flag Button
        IconButton(
          icon: Icon(
            Icons.flag_outlined,
            color: colors.textSecondary,
            size: 20,
          ),
          tooltip: l10n.tooltipReportThread,
          onPressed: () {
            unawaited(HapticFeedback.lightImpact());
            onReport();
          },
        ),

        // 3. Share Button
        IconButton(
          icon: Icon(
            Icons.share_outlined,
            color: colors.textSecondary,
            size: 20,
          ),
          tooltip: l10n.tooltipShareThread,
          onPressed: () {
            unawaited(HapticFeedback.lightImpact());
            onShare();
          },
        ),

        // 4. Close Panel Button (when presented inside 3-panel layout)
        if (onClosePanel != null) ...[
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
            tooltip: 'Close Forum Detail (Esc)',
            onPressed: onClosePanel,
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }
}
