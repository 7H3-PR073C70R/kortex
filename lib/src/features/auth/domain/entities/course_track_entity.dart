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
      description:
          'Senior secondary core curriculum (Sciences, Arts & Commercial)',
      iconName: 'school',
      examCountdownDays: 68,
    ),
    CourseTrackEntity(
      id: 'NECO',
      name: 'NECO / SSCE',
      description:
          'National Examinations Council Senior School Certificate Examination',
      iconName: 'assignment_turned_in',
      examCountdownDays: 75,
    ),
    CourseTrackEntity(
      id: 'JAMB',
      name: 'JAMB / UTME',
      description: 'High-speed CBT drills, subject combinations & past papers',
      iconName: 'timer',
      defaultDailyTarget: 25,
      examCountdownDays: 45,
    ),
    CourseTrackEntity(
      id: 'BSC',
      name: "B.Sc / B.A (Bachelor's Degree)",
      description:
          'Undergraduate university coursework across science, arts & humanities',
      iconName: 'history_edu',
      defaultDailyTarget: 25,
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'MSC',
      name: "M.Sc / M.A (Master's Degree)",
      description:
          'Postgraduate master degree studies, research & specialized seminars',
      iconName: 'workspace_premium',
      defaultDailyTarget: 30,
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'PhD',
      name: 'Ph.D (Doctorate Degree)',
      description:
          'Doctoral research, thesis defense & advanced scholarship',
      iconName: 'psychology',
      defaultDailyTarget: 30,
      examCountdownDays: 120,
    ),
    CourseTrackEntity(
      id: 'OND_I',
      name: 'OND I (National Diploma Year 1)',
      description:
          'First year foundational polytechnic & diploma coursework',
      iconName: 'menu_book',
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'OND_II',
      name: 'OND II (National Diploma Year 2)',
      description:
          'Second year polytechnic diploma coursework, projects & SIWES',
      iconName: 'menu_book',
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'HND_I',
      name: 'HND I (Higher National Diploma Year 1)',
      description:
          'Higher National Diploma year 1 specialized technological coursework',
      iconName: 'auto_stories',
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'HND_II',
      name: 'HND II (Higher National Diploma Year 2)',
      description:
          'Final year Higher National Diploma capstone & practical defense',
      iconName: 'auto_stories',
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'Vocational',
      name: 'Vocational & Technical Studies',
      description:
          'Technical colleges, trades, craftsmanship & TVET programs',
      iconName: 'handyman',
    ),
    CourseTrackEntity(
      id: 'Professional',
      name: 'Professional Certifications',
      description:
          'Professional licensing, chartered institutes & certified diplomas',
      iconName: 'verified',
      defaultDailyTarget: 25,
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
