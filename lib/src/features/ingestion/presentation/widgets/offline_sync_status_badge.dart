import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class OfflineSyncStatusBadge extends StatelessWidget {
  const OfflineSyncStatusBadge({
    required this.pendingCount,
    super.key,
    this.isSyncing = false,
    this.onSyncNow,
  });

  final int pendingCount;
  final bool isSyncing;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0 && !isSyncing) {
      return const SizedBox.shrink();
    }

    final theme = context.theme;
    final colors = context.colors;
    final l10n = context.l10n;
    final statusText = isSyncing
        ? 'Syncing offline notes...'
        : l10n.syncPendingCount(pendingCount);

    return Semantics(
      button: true,
      label: 'Offline OCR Sync Status: $statusText',
      hint: 'Tap to trigger immediate synchronization with cloud LaTeX AI',
      child: Material(
        color: colors.transparent,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return AnimatedScale(
              scale: isHovered && !isSyncing ? 1.04 : 1.0,
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              child: InkWell(
                onTap: isSyncing ? null : onSyncNow,
                borderRadius: BorderRadius.circular(AppRadius.badge),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.warning.withValues(alpha: 0.25)
                        : colors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: isHovered
                          ? colors.warning.withValues(alpha: 0.7)
                          : colors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSyncing)
                        AppLogoLoader(
                          size: 14,
                          color: colors.warning,
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isSyncing && onSyncNow != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.sync_rounded,
                          size: 14,
                          color: colors.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
