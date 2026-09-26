import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/sync/app_sync_engine.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/di/locator.dart';

class AppSyncBeacon extends HookWidget {
  const AppSyncBeacon({super.key});

  @override
  Widget build(BuildContext context) {
    if (!locator.isRegistered<AppSyncEngine>()) return const SizedBox.shrink();

    final syncEngine = locator<AppSyncEngine>();
    final syncStatus = useStream(syncEngine.syncStatusStream, initialData: SyncStatus.online).data;
    final pendingCount = useStream(syncEngine.pendingCountStream, initialData: 0).data;

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    var label = '';
    var statusColor = colors.transparent;
    var icon = Icons.cloud_done_rounded;
    var isVisible = false;

    if (syncStatus == SyncStatus.offline) {
      label = 'Offline mode';
      statusColor = colors.error;
      icon = Icons.cloud_off_rounded;
      isVisible = true;
    } else if (syncStatus == SyncStatus.syncing) {
      label = 'Syncing ($pendingCount changes)';
      statusColor = colors.warning;
      icon = Icons.sync_rounded;
      isVisible = true;
    } else if (syncStatus == SyncStatus.online && pendingCount != null && pendingCount > 0) {
      label = 'Pending sync ($pendingCount changes)';
      statusColor = colors.warning;
      icon = Icons.cloud_upload_rounded;
      isVisible = true;
    }

    return AnimatedPositioned(
      duration: AppMotion.standard,
      curve: AppMotion.easeOutCubic,
      top: isVisible ? MediaQuery.paddingOf(context).top + 8 : -100,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary.withAlpha(240) : colors.surfacePrimary.withAlpha(240),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: statusColor.withAlpha(120), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (syncStatus == SyncStatus.syncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: typography.caption.semiBold.copyWith(color: colors.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
