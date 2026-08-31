import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';

class CourseTrackModel extends Equatable {
  const CourseTrackModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    this.defaultDailyTarget = 20,
    this.examCountdownDays = 60,
  });

  factory CourseTrackModel.fromJson(Map<String, dynamic> json) {
    return CourseTrackModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'school',
      defaultDailyTarget:
          (json['default_daily_target'] as num?)?.toInt() ?? 20,
      examCountdownDays:
          (json['exam_countdown_days'] as num?)?.toInt() ?? 60,
    );
  }

  final String id;
  final String name;
  final String description;
  final String iconName;
  final int defaultDailyTarget;
  final int examCountdownDays;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'default_daily_target': defaultDailyTarget,
      'exam_countdown_days': examCountdownDays,
    };
  }

  CourseTrackEntity toEntity() {
    return CourseTrackEntity(
      id: id,
      name: name,
      description: description,
      iconName: iconName,
      defaultDailyTarget: defaultDailyTarget,
      examCountdownDays: examCountdownDays,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        iconName,
        defaultDailyTarget,
        examCountdownDays,
      ];
}
