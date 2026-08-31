import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
    final l10n = context.l10n;
    final statusText = isSyncing
        ? 'Syncing offline notes...'
        : l10n.syncPendingCount(pendingCount);

    return Semantics(
      button: true,
      label: 'Offline OCR Sync Status: $statusText',
      hint: 'Tap to trigger immediate synchronization with cloud LaTeX AI',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSyncing ? null : onSyncNow,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.amber.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isSyncing && onSyncNow != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: Colors.amber.shade200,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
