import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/domain/logic/execution_engine_router.dart';
import 'package:kortex/src/shared/hardware/services/device_performance_benchmark.dart';
import 'package:kortex/src/shared/hardware/services/hardware_guard_factory.dart';

void main() {
  group('ExecutionEngineRouter Routing & Stream Suite', () {
    late DevicePerformanceBenchmarkImpl benchmark;
    late HardwareGuardFactory guardFactory;
    late ExecutionEngineRouter router;

    setUp(() {
      benchmark = DevicePerformanceBenchmarkImpl(
        initialProfile: HardwareProfile.baseline(),
      );
      guardFactory = const HardwareGuardFactory();
      router = ExecutionEngineRouter(
        benchmark: benchmark,
        guardFactory: guardFactory,
      );
    });

    tearDown(() async {
      await benchmark.dispose();
    });

    test('routes baseline hardware to cloudEdge by default', () async {
      final decision = await router.routeExecution(
        userPrefersOfflineAi: false,
        isNetworkConnected: true,
      );

      expect(decision.executionMode, equals(AiExecutionMode.cloudEdge));
      expect(decision.canRunGguf, isTrue);
      expect(decision.canRunMlKit, isTrue);
    });

    test('streams updates when hardware shifts to thermal throttle', () async {
      final emissionList = <HardwareDecision>[];

      final subscription = router
          .watchExecutionRoute(
            userPrefersOfflineAi: true,
            isNetworkConnected: true,
          )
          .listen(emissionList.add);

      // Trigger high-end state and thermal throttling state
      benchmark
        ..updateMockProfile(
          const HardwareProfile(
            totalRamGb: 12,
            availableRamGb: 8,
            cpuCores: 8,
            batteryLevel: 0.85,
            isCharging: true,
            thermalState: ThermalStatus.nominal,
            networkQuality: NetworkQuality.high,
          ),
        )
        ..updateMockProfile(
          const HardwareProfile(
            totalRamGb: 12,
            availableRamGb: 8,
            cpuCores: 8,
            batteryLevel: 0.85,
            isCharging: true,
            thermalState: ThermalStatus.critical,
            networkQuality: NetworkQuality.high,
          ),
        );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissionList.length, equals(2));
      expect(emissionList[0].executionMode, equals(AiExecutionMode.localGguf));
      expect(emissionList[1].executionMode, equals(AiExecutionMode.cloudEdge));
      expect(
        emissionList[1].reason,
        equals(HardwareThrottleReason.thermalThrottled),
      );

      await subscription.cancel();
    });
  });
}
