import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';

part 'study_deck_model.freezed.dart';
part 'study_deck_model.g.dart';

@freezed
abstract class StudyDeckModel with _$StudyDeckModel {
  const factory StudyDeckModel({
    required String id,
    required String title,
    required String subject,
    required int totalCards,
    required int dueCards,
    required double retentionRate,
    required String lastReviewedIso,
    required String category,
    String? coverImageUrl,
    @Default(10) int estimatedMinutes,
    String? colorHex,
    @JsonKey(name: 'course_id') String? courseId,
    @JsonKey(name: 'course_code') String? courseCode,
  }) = _StudyDeckModel;

  const StudyDeckModel._();

  factory StudyDeckModel.fromJson(
    Map<String, dynamic> json,
  ) => StudyDeckModel(
    id: (json['id'] as String?) ?? '',
    title: (json['title'] ?? '') as String,
    subject: (json['subject'] ?? 'General') as String,
    totalCards: (json['totalCards'] ?? json['total_cards'] as num?)?.toInt() ?? 0,
    dueCards: (json['dueCards'] ?? json['due_cards'] as num?)?.toInt() ?? 0,
    retentionRate: (json['retentionRate'] ?? json['retention_rate'] ?? json['masteryRate'] ?? json['mastery_rate'] as num?)?.toDouble() ?? 0.0,
    lastReviewedIso: (json['lastReviewedIso'] ?? json['last_reviewed_iso'] ?? json['lastStudied'] ?? json['last_studied'] as String?) ?? DateTime.now().toIso8601String(),
    category: (json['category'] ?? 'General') as String,
    coverImageUrl: (json['coverImageUrl'] ?? json['cover_image_url']) as String?,
    estimatedMinutes: (json['estimatedMinutes'] ?? json['estimated_minutes'] as num?)?.toInt() ?? 10,
    colorHex: (json['colorHex'] ?? json['color_hex']) as String?,
    courseId: (json['courseId'] ?? json['course_id']) as String?,
    courseCode: (json['courseCode'] ?? json['course_code']) as String?,
  );

  StudyDeckEntity toEntity() => StudyDeckEntity(
    id: id,
    title: title,
    subject: subject,
    totalCards: totalCards,
    dueCards: dueCards,
    retentionRate: retentionRate,
    lastReviewed: DateTime.tryParse(lastReviewedIso) ?? DateTime.now(),
    category: category,
    coverImageUrl: coverImageUrl,
    estimatedMinutes: estimatedMinutes,
    colorHex: colorHex,
    courseId: courseId,
    courseCode: courseCode,
  );
}
