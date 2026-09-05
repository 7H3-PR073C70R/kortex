import 'package:equatable/equatable.dart';

/// Represents a single backend-configured curriculum metadata item
/// (e.g. standardized exam, faculty track, degree level, or study goal).
class CurriculumMetadataEntity extends Equatable {
  const CurriculumMetadataEntity({
    required this.id,
    required this.category,
    required this.key,
    required this.displayName,
    this.metadata = const {},
    this.isActive = true,
  });

  final String id;
  final String category;
  final String key;
  final String displayName;
  final Map<String, dynamic> metadata;
  final bool isActive;

  String get subtitle => metadata['subtitle'] as String? ?? '';
  String? get iconName => metadata['icon'] as String?;
  String? get track => metadata['track'] as String?;

  @override
  List<Object?> get props => [
        id,
        category,
        key,
        displayName,
        metadata,
        isActive,
      ];
}
