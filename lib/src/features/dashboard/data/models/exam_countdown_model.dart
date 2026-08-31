import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

part 'exam_countdown_model.freezed.dart';
part 'exam_countdown_model.g.dart';

@freezed
abstract class ExamCountdownModel with _$ExamCountdownModel {
  const factory ExamCountdownModel({
    required String id,
    required String examName,
    required String targetDateIso,
    required double syllabusProgress,
    required String subjectTrack,
    required int totalMockPapersAvailable,
    required int completedMocksCount,
    @Default('NATIONAL STANDARD') String badgeTitle,
  }) = _ExamCountdownModel;

  const ExamCountdownModel._();

  factory ExamCountdownModel.fromJson(Map<String, dynamic> json) =>
      _$ExamCountdownModelFromJson(json);

  ExamCountdownEntity toEntity() => ExamCountdownEntity(
    id: id,
    examName: examName,
    targetDate:
        DateTime.tryParse(targetDateIso) ??
        DateTime.now().add(const Duration(days: 30)),
    syllabusProgress: syllabusProgress,
    subjectTrack: subjectTrack,
    totalMockPapersAvailable: totalMockPapersAvailable,
    completedMocksCount: completedMocksCount,
    badgeTitle: badgeTitle,
  );
}
