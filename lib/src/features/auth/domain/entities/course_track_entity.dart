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
      id: 'SAT',
      name: 'SAT',
      description: 'Standardized Reading, Writing, Math & problem solving',
      iconName: 'calculate',
      examCountdownDays: 90,
    ),
    CourseTrackEntity(
      id: 'TOEFL',
      name: 'TOEFL iBT',
      description: 'Academic English Reading, Listening, Speaking & Writing',
      iconName: 'record_voice_over',
      examCountdownDays: 50,
    ),
    CourseTrackEntity(
      id: 'IELTS',
      name: 'IELTS',
      description:
          'International English language proficiency (Academic & General)',
      iconName: 'translate',
      examCountdownDays: 50,
    ),
    CourseTrackEntity(
      id: 'Medicine',
      name: 'Medicine & Health Sciences',
      description:
          'Anatomy, Physiology, Pharmacology, Pathology & Clinical Skills',
      iconName: 'medical_services',
      defaultDailyTarget: 35,
      examCountdownDays: 40,
    ),
    CourseTrackEntity(
      id: 'Law',
      name: 'Law & Jurisprudence',
      description:
          'Constitutional, Criminal, Torts, Commercial Law & Jurisprudence',
      iconName: 'gavel',
      defaultDailyTarget: 25,
      examCountdownDays: 45,
    ),
    CourseTrackEntity(
      id: 'Engineering',
      name: 'Engineering & Technology',
      description:
          'Mechanical, Electrical, Civil, Software & Applied Mathematics',
      iconName: 'engineering',
      defaultDailyTarget: 30,
      examCountdownDays: 35,
    ),
    CourseTrackEntity(
      id: 'Business',
      name: 'Business & Economics',
      description: 'Accounting, Finance, Economics, Marketing & Management',
      iconName: 'trending_up',
      defaultDailyTarget: 25,
      examCountdownDays: 40,
    ),
    CourseTrackEntity(
      id: 'Humanities',
      name: 'Arts & Humanities',
      description: 'Literature, History, Philosophy, Linguistics & Mass Comm',
      iconName: 'menu_book',
      examCountdownDays: 45,
    ),
    CourseTrackEntity(
      id: 'ComputerScience',
      name: 'Computer Science & AI',
      description: 'Algorithms, Data Structures, Operating Systems & Networks',
      iconName: 'terminal',
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
