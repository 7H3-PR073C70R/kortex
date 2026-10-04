import 'package:equatable/equatable.dart';

/// Represents the version configuration fetched from Supabase.
///
/// [platform]           — "ios" | "android"
/// [minimumVersion]     — The absolute oldest version that may use the app.
/// [currentVersion]     — The latest released version (shown in UI as "recommended").
/// [isForceUpdateActive] — Kill-switch: false means skip version checks entirely.
/// [storeUrl]           — Deep-link to the App Store / Play Store listing.
/// [updateMessage]      — Optional custom message shown on the gate screen.
class AppVersionEntity extends Equatable {
  const AppVersionEntity({
    required this.platform,
    required this.minimumVersion,
    required this.currentVersion,
    required this.isForceUpdateActive,
    required this.storeUrl,
    this.updateMessage,
  });

  final String platform;
  final String minimumVersion;
  final String currentVersion;
  final bool isForceUpdateActive;
  final String storeUrl;
  final String? updateMessage;

  @override
  List<Object?> get props => [
        platform,
        minimumVersion,
        currentVersion,
        isForceUpdateActive,
        storeUrl,
        updateMessage,
      ];
}
