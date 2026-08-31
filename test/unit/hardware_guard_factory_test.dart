import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/shared/hardware/services/device_performance_benchmark.dart';
import 'package:kortex/src/shared/hardware/services/hardware_guard_factory.dart';

void main() {
  group('HardwareGuardFactory Benchmark & Execution Mode Rules', () {
    const factory = HardwareGuardFactory();

    test('low RAM (<6GB) routes to cloudEdge when online', () {
      const profile = HardwareProfile(
        totalRamGb: 4,
        availableRamGb: 2,
        cpuCores: 4,
        batteryLevel: 0.80,
        isCharging: false,
        thermalState: ThermalStatus.nominal,
        networkQuality: NetworkQuality.high,
      );

      final decision = factory.evaluateHardware(
        profile: profile,
        userPrefersOfflineAi: true,
        isNetworkConnected: true,
      );

      expect(decision.executionMode, equals(AiExecutionMode.cloudEdge));
      expect(decision.canRunGguf, isFalse);
      expect(decision.canRunMlKit, isTrue);
      expect(decision.reason, equals(HardwareThrottleReason.lowRam));
    });

    test('low RAM (<6GB) offline routes to mlKitOnly with notice', () {
      const profile = HardwareProfile(
        totalRamGb: 4,
        availableRamGb: 1.5,
        cpuCores: 4,
        batteryLevel: 0.80,
        isCharging: false,
        thermalState: ThermalStatus.nominal,
        networkQuality: NetworkQuality.offline,
      );

      final decision = factory.evaluateHardware(
        profile: profile,
        userPrefersOfflineAi: true,
        isNetworkConnected: false,
      );

      expect(decision.executionMode, equals(AiExecutionMode.mlKitOnly));
      expect(decision.canRunGguf, isFalse);
      expect(decision.canRunMlKit, isTrue);
      expect(decision.fallbackNoticeKey, equals('offlineLowMemoryNotice'));
    });

    test('low battery (<15%) routes to cloudEdge for power saving', () {
      const profile = HardwareProfile(
        totalRamGb: 12,
        availableRamGb: 8,
        cpuCores: 8,
        batteryLevel: 0.10,
        isCharging: false,
        thermalState: ThermalStatus.nominal,
        networkQuality: NetworkQuality.high,
      );

      final decision = factory.evaluateHardware(
        profile: profile,
        userPrefersOfflineAi: true,
        isNetworkConnected: true,
      );

      expect(decision.executionMode, equals(AiExecutionMode.cloudEdge));
      expect(decision.canRunGguf, isFalse);
      expect(decision.reason, equals(HardwareThrottleReason.lowBattery));
    });

    test('severe thermal throttling disables local GGUF processing', () {
      const profile = HardwareProfile(
        totalRamGb: 16,
        availableRamGb: 10,
        cpuCores: 8,
        batteryLevel: 0.90,
        isCharging: true,
        thermalState: ThermalStatus.serious,
        networkQuality: NetworkQuality.high,
      );

      final decision = factory.evaluateHardware(
        profile: profile,
        userPrefersOfflineAi: true,
        isNetworkConnected: true,
      );

      expect(decision.executionMode, equals(AiExecutionMode.cloudEdge));
      expect(decision.canRunGguf, isFalse);
      expect(decision.reason, equals(HardwareThrottleReason.thermalThrottled));
    });

    test('high RAM (>=8GB) with user preference enables local GGUF', () {
      const profile = HardwareProfile(
        totalRamGb: 8,
        availableRamGb: 5,
        cpuCores: 8,
        batteryLevel: 0.75,
        isCharging: false,
        thermalState: ThermalStatus.nominal,
        networkQuality: NetworkQuality.high,
      );

      final decision = factory.evaluateHardware(
        profile: profile,
        userPrefersOfflineAi: true,
        isNetworkConnected: true,
      );

      expect(decision.executionMode, equals(AiExecutionMode.localGguf));
      expect(decision.canRunGguf, isTrue);
      expect(decision.canRunMlKit, isTrue);
      expect(decision.reason, equals(HardwareThrottleReason.none));
    });
  });
}
