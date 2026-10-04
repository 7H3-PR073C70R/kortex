import 'package:kortex/src/features/force_update/domain/entities/app_version_entity.dart';

/// JSON ↔ Domain model for the `app_version_config` Supabase table.
class AppVersionModel extends AppVersionEntity {
  const AppVersionModel({
    required super.platform,
    required super.minimumVersion,
    required super.currentVersion,
    required super.isForceUpdateActive,
    required super.storeUrl,
    super.updateMessage,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      platform: json['platform'] as String? ?? '',
      minimumVersion: json['minimum_version'] as String? ?? '0.0.0',
      currentVersion: json['current_version'] as String? ?? '0.0.0',
      isForceUpdateActive: json['is_force_update_active'] as bool? ?? false,
      storeUrl: json['store_url'] as String? ?? '',
      updateMessage: json['update_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'minimum_version': minimumVersion,
        'current_version': currentVersion,
        'is_force_update_active': isForceUpdateActive,
        'store_url': storeUrl,
        'update_message': updateMessage,
      };
}
