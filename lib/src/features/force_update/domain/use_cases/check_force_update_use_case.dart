import 'dart:io';

import 'package:kortex/src/features/force_update/domain/repositories/app_version_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of a version check.
sealed class VersionCheckResult {
  const VersionCheckResult();
}

/// The app is up-to-date; nothing to do.
class VersionUpToDate extends VersionCheckResult {
  const VersionUpToDate();
}

/// The user must update before they can continue.
class VersionForceRequired extends VersionCheckResult {
  const VersionForceRequired({
    required this.installedVersion,
    required this.minimumVersion,
    required this.storeUrl,
    required this.updateMessage,
  });

  final String installedVersion;
  final String minimumVersion;
  final String storeUrl;
  final String? updateMessage;
}

/// Determines whether the currently-installed app version satisfies the
/// minimum required version stored in Supabase.
///
/// Uses semantic-version comparison (major.minor.patch).
class CheckForceUpdateUseCase {
  const CheckForceUpdateUseCase({required AppVersionRepository repository})
      : _repository = repository;

  final AppVersionRepository _repository;

  Future<VersionCheckResult> call() async {
    final info = await PackageInfo.fromPlatform();
    final platform = _resolvePlatform();
    final installedVersion = info.version; // e.g. "2.1.0"

    final config = await _repository.fetchVersionConfig(platform);

    // Kill-switch: operator can disable force-update globally.
    if (!config.isForceUpdateActive) return const VersionUpToDate();

    final isOutdated =
        _compareVersions(installedVersion, config.minimumVersion) < 0;

    if (isOutdated) {
      return VersionForceRequired(
        installedVersion: installedVersion,
        minimumVersion: config.minimumVersion,
        storeUrl: config.storeUrl,
        updateMessage: config.updateMessage,
      );
    }

    return const VersionUpToDate();
  }

  /// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
  int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).toList();
    final partsB = b.split('.').map(int.tryParse).toList();
    final length =
        partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < length; i++) {
      final vA = i < partsA.length ? (partsA[i] ?? 0) : 0;
      final vB = i < partsB.length ? (partsB[i] ?? 0) : 0;
      if (vA != vB) return vA.compareTo(vB);
    }
    return 0;
  }

  /// Maps the current runtime platform to the slug stored in Supabase.
  ///
  /// Supported slugs: 'ios' | 'android' | 'macos' | 'windows' | 'linux'
  /// Unknown/web targets return 'web', which receives the safe fallback
  /// (`isForceUpdateActive = false`) from the data source.
  static String _resolvePlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'web'; // fallback — data source returns safe defaults
  }
}
