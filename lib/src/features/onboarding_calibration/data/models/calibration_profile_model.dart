import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

part 'calibration_profile_model.freezed.dart';
part 'calibration_profile_model.g.dart';

@freezed
abstract class CalibrationProfileModel with _$CalibrationProfileModel {
  const factory CalibrationProfileModel({
    @Default('higherEducation') String focus,
    String? higherEdLevel,
    String? higherEdField,
    @Default([]) List<String> higherEdGoals,
    String? highSchoolExam,
    @Default([]) List<String> highSchoolSubjects,
    String? highSchoolTimeline,
    @Default(false) bool isCalibrated,
  }) = _CalibrationProfileModel;

  const CalibrationProfileModel._();

  factory CalibrationProfileModel.fromJson(Map<String, dynamic> json) =>
      _$CalibrationProfileModelFromJson(json);

  factory CalibrationProfileModel.fromEntity(CalibrationProfile entity) {
    return CalibrationProfileModel(
      focus: entity.focus.name,
      higherEdLevel: entity.higherEdLevel?.name,
      higherEdField: entity.higherEdField,
      higherEdGoals: entity.higherEdGoals,
      highSchoolExam: entity.highSchoolExam,
      highSchoolSubjects: entity.highSchoolSubjects,
      highSchoolTimeline: entity.highSchoolTimeline,
      isCalibrated: entity.isCalibrated,
    );
  }

  CalibrationProfile toEntity() {
    return CalibrationProfile(
      focus: AcademicFocus.values.firstWhere(
        (e) => e.name == focus,
        orElse: () => AcademicFocus.higherEducation,
      ),
      higherEdLevel: higherEdLevel != null
          ? HigherEdLevel.values.firstWhere(
              (e) => e.name == higherEdLevel,
              orElse: () => HigherEdLevel.bsc,
            )
          : null,
      higherEdField: higherEdField,
      higherEdGoals: higherEdGoals,
      highSchoolExam: highSchoolExam,
      highSchoolSubjects: highSchoolSubjects,
      highSchoolTimeline: highSchoolTimeline,
      isCalibrated: isCalibrated,
    );
  }
}
