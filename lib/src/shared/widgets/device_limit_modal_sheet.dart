import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class ActiveDeviceInfo {
  const ActiveDeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.lastActiveAt,
  });

  factory ActiveDeviceInfo.fromJson(Map<String, dynamic> json) {
    return ActiveDeviceInfo(
      deviceId: json['device_id'] as String? ?? json['id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? 'Kortex Device',
      platform: json['platform'] as String? ?? 'other',
      lastActiveAt: json['last_active_at'] as String?,
    );
  }

  final String deviceId;
  final String deviceName;
  final String platform;
  final String? lastActiveAt;
}

/// Modal Sheet presented when a user exceeds their 3-device slot quota.
/// Allows the user to remotely sign out an old device to free up a slot for the current device.
class DeviceLimitModalSheet extends StatefulWidget {
  const DeviceLimitModalSheet({
    required this.activeDevices,
    required this.onDisconnectDevice,
    super.key,
  });

  final List<ActiveDeviceInfo> activeDevices;
  final Future<bool> Function(String deviceId) onDisconnectDevice;

  static Future<bool?> show(
    BuildContext context, {
    required List<ActiveDeviceInfo> activeDevices,
    required Future<bool> Function(String deviceId) onDisconnectDevice,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeviceLimitModalSheet(
        activeDevices: activeDevices,
        onDisconnectDevice: onDisconnectDevice,
      ),
    );
  }

  @override
  State<DeviceLimitModalSheet> createState() => _DeviceLimitModalSheetState();
}

class _DeviceLimitModalSheetState extends State<DeviceLimitModalSheet> {
  String? _disconnectingDeviceId;

  Future<void> _handleDisconnect(String deviceId) async {
    AppFeedback.selection();
    setState(() => _disconnectingDeviceId = deviceId);

    try {
      final success = await widget.onDisconnectDevice(deviceId);
      if (mounted) {
        if (success) {
          AppFeedback.celebration();
          Navigator.of(context).pop(true);
        } else {
          setState(() => _disconnectingDeviceId = null);
        }
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _disconnectingDeviceId = null);
      }
    }
  }

  IconData _getDeviceIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('ios') || lower.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    } else if (lower.contains('android')) {
      return Icons.phone_android_rounded;
    } else if (lower.contains('web')) {
      return Icons.language_rounded;
    } else if (lower.contains('mac') || lower.contains('desktop') || lower.contains('windows')) {
      return Icons.laptop_mac_rounded;
    }
    return Icons.devices_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceBorder.withAlpha(120),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.warning.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.devices_other_rounded,
                  color: colors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Limit Reached (3/3)',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a device to sign out and continue on this device.',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...widget.activeDevices.map((device) {
            final isDisconnecting = _disconnectingDeviceId == device.deviceId;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceTertiary.withAlpha(150)
                    : colors.backgroundPrimary,
                borderRadius: AppRadius.radiusPanel,
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(25),
                      borderRadius: AppRadius.radiusCard,
                    ),
                    child: Icon(
                      _getDeviceIcon(device.platform),
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Platform: ${device.platform.toUpperCase()}',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShrinkableButton(
                    onTap: isDisconnecting
                        ? null
                        : () => _handleDisconnect(device.deviceId),
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(20),
                        borderRadius: AppRadius.radiusBadge,
                        border: Border.all(
                          color: colors.error.withAlpha(100),
                        ),
                      ),
                      child: isDisconnecting
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.error,
                              ),
                            )
                          : Text(
                              'Sign Out',
                              style: typography.caption.bold.copyWith(
                                color: colors.error,
                                fontSize: 11.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
