import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Performance and capacity evaluation for on-device Local LLM execution.
class DeviceCapabilityReport {
  const DeviceCapabilityReport({
    required this.cpuCores,
    required this.hasSufficientStorage,
    required this.availableStorageMb,
    required this.requiredStorageMb,
    required this.isRecommended,
    required this.recommendationText,
    required this.storageStatusText,
    required this.performanceTier,
  });

  final int cpuCores;
  final bool hasSufficientStorage;
  final int availableStorageMb;
  final int requiredStorageMb;
  final bool isRecommended;
  final String recommendationText;
  final String storageStatusText;
  final String performanceTier;
}

class DeviceCapabilityService {
  static const int requiredModelStorageMb = 248;
  static const int recommendedStorageBufferMb = 500;

  /// Audits the host device processor, storage, and platform suitability for on-device GGUF inference.
  Future<DeviceCapabilityReport> auditDeviceCapacity() async {
    final cpuCores = Platform.numberOfProcessors;
    var availableMb = 2048; // Safe fallback assumption in MB

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
    final isOptimalCores = cpuCores >= 4;
    final isRecommended = hasSufficientStorage && isOptimalCores;

    String performanceTier;
    if (cpuCores >= 8) {
      performanceTier = 'High Performance (Neural / Multi-Core)';
    } else if (cpuCores >= 4) {
      performanceTier = 'Optimal (Standard Multi-Core)';
    } else {
      performanceTier = 'Moderate (Power-Saving Mode Recommended)';
    }

    final String recommendationText;
    if (isRecommended) {
      recommendationText =
          'Your device meets all requirements for smooth on-device inference with low battery impact.';
    } else if (!hasSufficientStorage) {
      recommendationText =
          'Storage space is limited. Free up space or continue with Cloud AI Engine.';
    } else {
      recommendationText =
          'On-device AI is supported, but Cloud AI may provide faster response times.';
    }

    final storageText = hasSufficientStorage
        ? 'Sufficient space available (${requiredModelStorageMb}MB required)'
        : 'Low storage warning (${requiredModelStorageMb}MB required)';

    return DeviceCapabilityReport(
      cpuCores: cpuCores,
      hasSufficientStorage: hasSufficientStorage,
      availableStorageMb: availableMb,
      requiredStorageMb: requiredModelStorageMb,
      isRecommended: isRecommended,
      recommendationText: recommendationText,
      storageStatusText: storageText,
      performanceTier: performanceTier,
    );
  }
}
