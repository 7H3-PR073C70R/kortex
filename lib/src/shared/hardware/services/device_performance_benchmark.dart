import 'dart:async';
import 'dart:io';

enum ThermalStatus {
  nominal,
  fair,
  serious,
  critical,
}

enum NetworkQuality {
  high,
  moderate,
  poor,
  offline,
}

class HardwareProfile {
  const HardwareProfile({
    required this.totalRamGb,
    required this.availableRamGb,
    required this.cpuCores,
    required this.batteryLevel,
    required this.isCharging,
    required this.thermalState,
    required this.networkQuality,
  });

  /// Default baseline profile for mocking or initial state
  factory HardwareProfile.baseline() {
    final cores = Platform.numberOfProcessors;
    return HardwareProfile(
      totalRamGb: 8,
      availableRamGb: 4.5,
      cpuCores: cores > 0 ? cores : 8,
      batteryLevel: 0.85,
      isCharging: true,
      thermalState: ThermalStatus.nominal,
      networkQuality: NetworkQuality.high,
    );
  }

  final double totalRamGb;
  final double availableRamGb;
  final int cpuCores;
  final double batteryLevel; // 0.0 to 1.0 (e.g., 0.85 = 85%)
  final bool isCharging;
  final ThermalStatus thermalState;
  final NetworkQuality networkQuality;

  bool get isThermalThrottled =>
      thermalState == ThermalStatus.serious ||
      thermalState == ThermalStatus.critical;

  bool get isBatteryLow => batteryLevel < 0.15 && !isCharging;

  bool get isOffline => networkQuality == NetworkQuality.offline;

  HardwareProfile copyWith({
    double? totalRamGb,
    double? availableRamGb,
    int? cpuCores,
    double? batteryLevel,
    bool? isCharging,
    ThermalStatus? thermalState,
    NetworkQuality? networkQuality,
  }) {
    return HardwareProfile(
      totalRamGb: totalRamGb ?? this.totalRamGb,
      availableRamGb: availableRamGb ?? this.availableRamGb,
      cpuCores: cpuCores ?? this.cpuCores,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      thermalState: thermalState ?? this.thermalState,
      networkQuality: networkQuality ?? this.networkQuality,
    );
  }
}

abstract class DevicePerformanceBenchmark {
  Future<HardwareProfile> getHardwareProfile();
  Stream<HardwareProfile> watchHardwareProfile();
}

class DevicePerformanceBenchmarkImpl implements DevicePerformanceBenchmark {
  DevicePerformanceBenchmarkImpl({HardwareProfile? initialProfile})
      : _currentProfile = initialProfile ?? HardwareProfile.baseline();

  HardwareProfile _currentProfile;
  final _profileController = StreamController<HardwareProfile>.broadcast();

  @override
  Future<HardwareProfile> getHardwareProfile() async {
    // In production: integrates with sysinfo, battery_plus, & connectivity
    return _currentProfile;
  }

  @override
  Stream<HardwareProfile> watchHardwareProfile() {
    return _profileController.stream;
  }

  /// Utility for tests or manual hardware state simulation
  void updateMockProfile(HardwareProfile newProfile) {
    _currentProfile = newProfile;
    _profileController.add(newProfile);
  }

  Future<void> dispose() async {
    await _profileController.close();
  }
}
