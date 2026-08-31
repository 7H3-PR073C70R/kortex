import 'package:equatable/equatable.dart';

/// Represents an academic track option available for curriculum onboarding.
class CourseTrackEntity extends Equatable {
  const CourseTrackEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    this.defaultDailyTarget = 20,
    this.examCountdownDays = 60,
  });

  final String id;
  final String name;
  final String description;
  final String iconName;
  final int defaultDailyTarget;
  final int examCountdownDays;

  static const List<CourseTrackEntity> defaultTracks = [
    CourseTrackEntity(
      id: 'WAEC',
      name: 'WAEC / WASSCE',
      description: 'Senior secondary school core curriculum & STEM exams',
      iconName: 'school',
      examCountdownDays: 68,
    ),
    CourseTrackEntity(
      id: 'JAMB',
      name: 'JAMB / UTME',
      description: 'High-speed multiple choice drills & past questions',
      iconName: 'timer',
      defaultDailyTarget: 25,
      examCountdownDays: 45,
    ),
    CourseTrackEntity(
      id: 'SAT',
      name: 'SAT STEM',
      description: 'Standardized math, geometry, and problem solving',
      iconName: 'calculate',
      defaultDailyTarget: 15,
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'University',
      name: 'University STEM',
      description: 'Engineering, physics, calculus, and biochemistry',
      iconName: 'biotech',
      defaultDailyTarget: 30,
      examCountdownDays: 30,
    ),
  ];

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
