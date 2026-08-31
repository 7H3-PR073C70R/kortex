import 'dart:async';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/hardware/services/device_performance_benchmark.dart';
import 'package:kortex/src/shared/hardware/services/hardware_guard_factory.dart';

class ExecutionEngineRouter {
  const ExecutionEngineRouter({
    required DevicePerformanceBenchmark benchmark,
    required HardwareGuardFactory guardFactory,
  })  : _benchmark = benchmark,
        _guardFactory = guardFactory;

  final DevicePerformanceBenchmark _benchmark;
  final HardwareGuardFactory _guardFactory;

  /// Resolves the optimal AI execution engine decision.
  Future<HardwareDecision> routeExecution({
    required bool userPrefersOfflineAi,
    required bool isNetworkConnected,
  }) async {
    final profile = await _benchmark.getHardwareProfile();
    return _guardFactory.evaluateHardware(
      profile: profile,
      userPrefersOfflineAi: userPrefersOfflineAi,
      isNetworkConnected: isNetworkConnected,
    );
  }

  /// Reactive stream of execution decisions when hardware metrics shift.
  Stream<HardwareDecision> watchExecutionRoute({
    required bool userPrefersOfflineAi,
    required bool isNetworkConnected,
  }) {
    return _benchmark.watchHardwareProfile().map(
          (profile) => _guardFactory.evaluateHardware(
            profile: profile,
            userPrefersOfflineAi: userPrefersOfflineAi,
            isNetworkConnected: isNetworkConnected,
          ),
        );
  }

  /// Maps internal notice keys to localized UI string messages.
  String? resolveLocalizedNotice(String? noticeKey, AppLocalizations l10n) {
    if (noticeKey == null) return null;
    switch (noticeKey) {
      case 'offlineLowMemoryNotice':
        return l10n.offlineLowMemoryNotice;
      case 'hardwareThermalThrottled':
        return l10n.hardwareThermalThrottled;
      case 'hardwareBatterySavingActive':
        return l10n.hardwareBatterySavingActive;
      default:
        return null;
    }
  }
}
