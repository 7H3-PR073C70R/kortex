import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Represents an active authenticated device session.
class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.osType,
    required this.ipAddress,
    required this.location,
    required this.lastActive,
    this.isCurrentDevice = false,
  });

  final String id;
  final String deviceName;
  final String osType; // 'ios', 'android', 'macos', 'windows', 'web'
  final String ipAddress;
  final String location;
  final DateTime lastActive;
  final bool isCurrentDevice;
}

/// Active logged-in device sessions manager widget (SEC-08).
class ActiveSessionsListWidget extends HookWidget {
  const ActiveSessionsListWidget({
    required this.sessions, super.key,
    this.onRevokeSession,
    this.onRevokeAllOthers,
  });

  final List<DeviceSession> sessions;
  final ValueChanged<String>? onRevokeSession;
  final VoidCallback? onRevokeAllOthers;

  IconData _getDeviceIcon(String osType) {
    switch (osType.toLowerCase()) {
      case 'ios':
      case 'iphone':
        return Icons.phone_iphone_rounded;
      case 'android':
        return Icons.phone_android_rounded;
      case 'macos':
      case 'mac':
        return Icons.laptop_mac_rounded;
      case 'windows':
        return Icons.desktop_windows_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final sessionList = useState<List<DeviceSession>>(sessions);

    void revokeSession(String sessionId) {
      AppFeedback.light();
      sessionList.value = sessionList.value.where((s) => s.id != sessionId).toList();
      onRevokeSession?.call(sessionId);
    }

    void revokeAllOthers() {
      AppFeedback.correct();
      sessionList.value = sessionList.value.where((s) => s.isCurrentDevice).toList();
      onRevokeAllOthers?.call();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Logins (${sessionList.value.length})',
                style: typography.title2.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (sessionList.value.length > 1)
                TextButton(
                  onPressed: revokeAllOthers,
                  child: Text(
                    'Log Out Others',
                    style: typography.caption.regular.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Sessions List
        Expanded(
          child: ListView.builder(
            itemCount: sessionList.value.length,
            itemBuilder: (context, index) {
              final session = sessionList.value[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: session.isCurrentDevice
                        ? colors.primary.withValues(alpha: 0.4)
                        : colors.surfaceBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: session.isCurrentDevice
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getDeviceIcon(session.osType),
                        size: 24,
                        color: session.isCurrentDevice ? colors.primary : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                session.deviceName,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (session.isCurrentDevice) ...[
                                const SizedBox(width: 6),
                                const AppBadge(
                                  label: 'This Device',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${session.location} • ${session.ipAddress}',
                            style: typography.caption.regular.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!session.isCurrentDevice)
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        color: colors.error,
                        tooltip: 'Revoke session',
                        onPressed: () => revokeSession(session.id),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
