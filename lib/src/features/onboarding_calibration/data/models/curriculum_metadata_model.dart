import 'package:kortex/src/features/onboarding_calibration/domain/entities/curriculum_metadata_entity.dart';

class CurriculumMetadataModel {
  const CurriculumMetadataModel({
    required this.id,
    required this.category,
    required this.key,
    required this.displayName,
    this.metadata = const {},
    this.isActive = true,
  });

  factory CurriculumMetadataModel.fromJson(Map<String, dynamic> json) {
    return CurriculumMetadataModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      key: json['key'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String category;
  final String key;
  final String displayName;
  final Map<String, dynamic> metadata;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'key': key,
      'display_name': displayName,
      'metadata': metadata,
      'is_active': isActive,
    };
  }

  CurriculumMetadataEntity toEntity() {
    return CurriculumMetadataEntity(
      id: id,
      category: category,
      key: key,
      displayName: displayName,
      metadata: metadata,
      isActive: isActive,
    );
  }
}
