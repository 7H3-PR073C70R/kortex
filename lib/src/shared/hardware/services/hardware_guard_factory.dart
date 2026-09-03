import 'package:kortex/src/shared/hardware/services/device_performance_benchmark.dart';

enum AiExecutionMode {
  cloudEdge,
  localGguf,
  mlKitOnly,
}

enum HardwareThrottleReason {
  none,
  lowRam,
  lowBattery,
  thermalThrottled,
  userPreferenceDisabled,
  networkOffline,
}

class HardwareDecision {
  const HardwareDecision({
    required this.executionMode,
    required this.reason,
    required this.canRunGguf,
    required this.canRunMlKit,
    required this.isCloudPreferred,
    this.fallbackNoticeKey,
  });

  final AiExecutionMode executionMode;
  final HardwareThrottleReason reason;
  final bool canRunGguf;
  final bool canRunMlKit;
  final bool isCloudPreferred;
  final String? fallbackNoticeKey;
}

class HardwareGuardFactory {
  const HardwareGuardFactory();

  /// Evaluates device hardware constraints and routes AI execution mode.
  ///
  /// Criteria:
  /// 1. If RAM < 6 GB, Battery < 15% (not charging), or Thermal is serious/crit:
  ///    - Local heavy AI (llama.cpp) is strictly disabled.
  ///    - Local processing is restricted to lightweight MLKit OCR only.
  ///    - If online -> cloudEdge.
  ///    - If offline -> mlKitOnly with offlineLowMemoryNotice.
  /// 2. If RAM >= 8 GB, Thermal is normal/fair, Battery >= 15%, AND user enabled:
  ///    - executionMode -> localGguf.
  /// 3. Otherwise (default):
  ///    - executionMode -> cloudEdge.
  HardwareDecision evaluateHardware({
    required HardwareProfile profile,
    required bool userPrefersOfflineAi,
    required bool isNetworkConnected,
  }) {
    final hasLowRam = profile.totalRamGb < 6.0;
    final isBatteryLow = profile.isBatteryLow;
    final isThermalThrottled = profile.isThermalThrottled;

    // Rule 1: Constrained Hardware Restrictions
    if (hasLowRam || isBatteryLow || isThermalThrottled) {
      var reason = HardwareThrottleReason.lowRam;
      if (isThermalThrottled) {
        reason = HardwareThrottleReason.thermalThrottled;
      } else if (isBatteryLow) {
        reason = HardwareThrottleReason.lowBattery;
      }

      if (isNetworkConnected) {
        return HardwareDecision(
          executionMode: AiExecutionMode.cloudEdge,
          reason: reason,
          canRunGguf: false,
          canRunMlKit: true,
          isCloudPreferred: true,
        );
      } else {
        return const HardwareDecision(
          executionMode: AiExecutionMode.mlKitOnly,
          reason: HardwareThrottleReason.networkOffline,
          canRunGguf: false,
          canRunMlKit: true,
          isCloudPreferred: false,
          fallbackNoticeKey: 'offlineLowMemoryNotice',
        );
      }
    }

    // Rule 2: High-End Hardware with Offline Local AI Toggle
    final hasHighRam = profile.totalRamGb >= 8.0;
    if (hasHighRam && userPrefersOfflineAi) {
      return const HardwareDecision(
        executionMode: AiExecutionMode.localGguf,
        reason: HardwareThrottleReason.none,
        canRunGguf: true,
        canRunMlKit: true,
        isCloudPreferred: false,
      );
    }

    // Rule 3: Default Cloud-Edge Fast Inference
    return HardwareDecision(
      executionMode: isNetworkConnected
          ? AiExecutionMode.cloudEdge
          : (profile.totalRamGb >= 8.0
                ? AiExecutionMode.localGguf
                : AiExecutionMode.mlKitOnly),
      reason: userPrefersOfflineAi
          ? HardwareThrottleReason.none
          : HardwareThrottleReason.userPreferenceDisabled,
      canRunGguf: profile.totalRamGb >= 8.0,
      canRunMlKit: true,
      isCloudPreferred: isNetworkConnected,
      fallbackNoticeKey: (!isNetworkConnected && profile.totalRamGb < 8.0)
          ? 'offlineLowMemoryNotice'
          : null,
    );
  }
}
