import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/hardware/services/device_performance_benchmark.dart';
import 'package:path_provider/path_provider.dart';

/// Performance and capacity evaluation for On-Device AI execution.
class DeviceCapabilityReport {
  const DeviceCapabilityReport({
    required this.cpuCores,
    required this.hasSufficientCpu,
    required this.hasSufficientStorage,
    required this.hasSufficientMemory,
    required this.availableStorageMb,
    required this.requiredStorageMb,
    required this.totalRamGb,
    required this.isSupported,
    required this.isRecommended,
    required this.recommendationText,
    required this.storageStatusText,
    required this.performanceTier,
    this.unsupportedReason,
  });

  final int cpuCores;
  final bool hasSufficientCpu;
  final bool hasSufficientStorage;
  final bool hasSufficientMemory;
  final int availableStorageMb;
  final int requiredStorageMb;
  final double totalRamGb;
  final bool isSupported;
  final bool isRecommended;
  final String recommendationText;
  final String storageStatusText;
  final String performanceTier;
  final String? unsupportedReason;
}

class DeviceCapabilityService {
  static const int requiredModelStorageMb = 248;
  static const int recommendedStorageBufferMb = 500;
  static const int minCpuCores = 4;
  static const double minRamGb = 4;

  /// Audits the host device processor, storage, and platform suitability for On-Device AI inference.
  Future<DeviceCapabilityReport> auditDeviceCapacity() async {
    final cpuCores = Platform.numberOfProcessors;
    var availableMb = 2048; // Safe fallback assumption in MB
    var totalRamGb = 8.0;

    try {
      if (locator.isRegistered<DevicePerformanceBenchmark>()) {
        final profile =
            await locator<DevicePerformanceBenchmark>().getHardwareProfile();
        totalRamGb = profile.totalRamGb;
      }
    } on Object catch (_) {}

    try {
      final docDir = await getApplicationDocumentsDirectory();
      // Inspect storage via file stat or root directory check
      if (docDir.existsSync()) {
        final stat = docDir.statSync();
        if (stat.size > 0) {
          availableMb = (stat.size / (1024 * 1024)).round();
        }
      }
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceCapabilityService] Storage audit note: $e');
      }
    }

    final hasSufficientStorage = availableMb >= requiredModelStorageMb;
    final hasSufficientCpu = cpuCores >= minCpuCores;
    final hasSufficientMemory = totalRamGb >= minRamGb;
    final isSupported =
        hasSufficientStorage && hasSufficientCpu && hasSufficientMemory;
    final isRecommended = isSupported && cpuCores >= 6;

    String performanceTier;
    if (cpuCores >= 8) {
      performanceTier = 'High Performance (Neural / Multi-Core)';
    } else if (cpuCores >= 4) {
      performanceTier = 'Optimal (Standard Multi-Core)';
    } else {
      performanceTier = 'Moderate (Power-Saving Mode Recommended)';
    }

    String? unsupportedReason;
    if (!hasSufficientCpu) {
      unsupportedReason =
          'At least $minCpuCores CPU cores are required for On-Device AI ($cpuCores detected).';
    } else if (!hasSufficientStorage) {
      unsupportedReason =
          'At least ${requiredModelStorageMb}MB of free storage is required for On-Device AI.';
    } else if (!hasSufficientMemory) {
      unsupportedReason =
          'At least ${minRamGb.toInt()}GB RAM is required for On-Device AI.';
    }

    final String recommendationText;
    if (isRecommended) {
      recommendationText =
          'Your device meets all requirements for smooth on-device AI inference with low battery impact.';
    } else if (isSupported) {
      recommendationText =
          'Your device supports On-Device AI. You can run reasoning locally or use Cloud AI.';
    } else {
      recommendationText = unsupportedReason ??
          'Your device does not meet the hardware capacity requirements for On-Device AI.';
    }

    final storageText = hasSufficientStorage
        ? 'Sufficient space available (${requiredModelStorageMb}MB required)'
        : 'Low storage warning (${requiredModelStorageMb}MB required)';

    return DeviceCapabilityReport(
      cpuCores: cpuCores,
      hasSufficientCpu: hasSufficientCpu,
      hasSufficientStorage: hasSufficientStorage,
      hasSufficientMemory: hasSufficientMemory,
      availableStorageMb: availableMb,
      requiredStorageMb: requiredModelStorageMb,
      totalRamGb: totalRamGb,
      isSupported: isSupported,
      isRecommended: isRecommended,
      recommendationText: recommendationText,
      storageStatusText: storageText,
      performanceTier: performanceTier,
      unsupportedReason: unsupportedReason,
    );
  }
}
