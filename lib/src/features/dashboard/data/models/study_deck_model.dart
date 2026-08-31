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
  }) = _StudyDeckModel;

  const StudyDeckModel._();

  factory StudyDeckModel.fromJson(Map<String, dynamic> json) =>
      _$StudyDeckModelFromJson(json);

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
  );
}
