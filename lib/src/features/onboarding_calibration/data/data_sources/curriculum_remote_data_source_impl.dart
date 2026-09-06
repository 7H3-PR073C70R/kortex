import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/constants/subject_catalog.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/curriculum_metadata_model.dart';

class CurriculumRemoteDataSourceImpl implements CurriculumRemoteDataSource {
  CurriculumRemoteDataSourceImpl(this._dio, {CrashlyticsService? crashlytics})
      : _crashlyticsOverride = crashlytics;

  final Dio _dio;
  final CrashlyticsService? _crashlyticsOverride;

  CrashlyticsService? get _crashlyticsService {
    if (_crashlyticsOverride != null) return _crashlyticsOverride;
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<List<CurriculumMetadataModel>> fetchMetadataByCategory(
    String category,
  ) async {
    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.curriculumMetadata}&category=eq.$category';
      final response = await _dio.get<dynamic>(
        endpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 && response.data is List) {
        final rawList = response.data as List<dynamic>;
        if (rawList.isNotEmpty) {
          return rawList
              .map(
                (item) => CurriculumMetadataModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
      return getFallbackByCategory(category);
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'CurriculumRemoteDataSource.fetchMetadataByCategory failed for $category',
          ),
        );
      }
      return getFallbackByCategory(category);
    }
  }

  @override
  Future<List<CurriculumMetadataModel>> fetchAllMetadata() async {
    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.curriculumMetadata}';
      final response = await _dio.get<dynamic>(
        endpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 && response.data is List) {
        final rawList = response.data as List<dynamic>;
        if (rawList.isNotEmpty) {
          return rawList
              .map(
                (item) => CurriculumMetadataModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
      return getAllFallbackMetadata();
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'CurriculumRemoteDataSource.fetchAllMetadata failed, using offline defaults',
          ),
        );
      }
      return getAllFallbackMetadata();
    }
  }

  List<CurriculumMetadataModel> getFallbackByCategory(String category) {
    switch (category) {
      case 'standardized_exam':
        return fallbackStandardizedExams;
      case 'faculty_track':
        return fallbackFacultyTracks;
      case 'higher_ed_level':
        return fallbackHigherEdLevels;
      case 'study_goal':
        return fallbackStudyGoals;
      case 'high_school_subject':
        return fallbackHighSchoolSubjects;
      default:
        return const [];
    }
  }

  List<CurriculumMetadataModel> getAllFallbackMetadata() {
    return [
      ...fallbackStandardizedExams,
      ...fallbackFacultyTracks,
      ...fallbackHigherEdLevels,
      ...fallbackStudyGoals,
      ...fallbackHighSchoolSubjects,
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Offline / Network Fallback Constants
  // ──────────────────────────────────────────────────────────────────────────

  static const List<CurriculumMetadataModel> fallbackStandardizedExams = [
    CurriculumMetadataModel(
      id: 'fb-exam-1',
      category: 'standardized_exam',
      key: 'jamb',
      displayName: 'JAMB / UTME',
      metadata: {
        'subtitle': 'Unified Tertiary Matriculation Examination',
        'icon': 'quiz_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-exam-2',
      category: 'standardized_exam',
      key: 'waec',
      displayName: 'WAEC / WASSCE',
      metadata: {
        'subtitle': 'West African Senior School Certificate Examination',
        'icon': 'school_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-exam-3',
      category: 'standardized_exam',
      key: 'neco',
      displayName: 'NECO / SSCE',
      metadata: {
        'subtitle':
            'National Examination Council Senior School Certificate',
        'icon': 'assignment_turned_in_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-exam-4',
      category: 'standardized_exam',
      key: 'sat',
      displayName: 'College Board SAT',
      metadata: {
        'subtitle': 'College Board SAT Reasoning & Subject Tests',
        'icon': 'public_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-exam-5',
      category: 'standardized_exam',
      key: 'igcse',
      displayName: 'Cambridge IGCSE / A-Levels',
      metadata: {
        'subtitle': 'Cambridge IGCSE, AS & A-Levels Syllabus',
        'icon': 'military_tech_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-exam-6',
      category: 'standardized_exam',
      key: 'ielts',
      displayName: 'IELTS / TOEFL',
      metadata: {
        'subtitle': 'English Language Proficiency Certification',
        'icon': 'translate_rounded',
      },
    ),
  ];

  static const List<CurriculumMetadataModel> fallbackFacultyTracks = [
    CurriculumMetadataModel(
      id: 'fb-track-1',
      category: 'faculty_track',
      key: 'cs',
      displayName: 'Computer Science & Engineering',
      metadata: {
        'subtitle': 'Algorithms, Data Structures, AI/ML, Distributed Systems',
        'icon': 'memory_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-2',
      category: 'faculty_track',
      key: 'medicine',
      displayName: 'Medicine & Health Sciences',
      metadata: {
        'subtitle':
            'Anatomy, Biochemistry, Pharmacology, Pathology, Surgery',
        'icon': 'medical_services_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-3',
      category: 'faculty_track',
      key: 'law',
      displayName: 'Law & Legal Studies',
      metadata: {
        'subtitle':
            'Case Law, Constitutional Law, Jurisprudence, Legal Writing',
        'icon': 'gavel_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-4',
      category: 'faculty_track',
      key: 'business',
      displayName: 'Business & Economics',
      metadata: {
        'subtitle':
            'Finance, Accounting, Economics, Management, Marketing',
        'icon': 'business_center_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-5',
      category: 'faculty_track',
      key: 'humanities',
      displayName: 'Humanities & Arts',
      metadata: {
        'subtitle':
            'Literature, History, Philosophy, Linguistics, Cultural Studies',
        'icon': 'menu_book_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-6',
      category: 'faculty_track',
      key: 'social_sciences',
      displayName: 'Social Sciences',
      metadata: {
        'subtitle': 'Sociology, Political Science, Psychology, Geography',
        'icon': 'groups_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-7',
      category: 'faculty_track',
      key: 'math',
      displayName: 'Mathematics & Statistics',
      metadata: {
        'subtitle':
            'Calculus, Linear Algebra, Statistics, Probability Theory',
        'icon': 'functions_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-8',
      category: 'faculty_track',
      key: 'physics',
      displayName: 'Physics & Electronics',
      metadata: {
        'subtitle': 'Quantum Mechanics, Thermodynamics, Electromagnetism',
        'icon': 'blur_on_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-9',
      category: 'faculty_track',
      key: 'chemical_eng',
      displayName: 'Chemical & Bio Engineering',
      metadata: {
        'subtitle':
            'Organic Synthesis, Fluid Mechanics, Reaction Kinetics',
        'icon': 'science_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-track-10',
      category: 'faculty_track',
      key: 'robotics',
      displayName: 'Robotics & Mechatronics',
      metadata: {
        'subtitle': 'Control Theory, Mechatronics, Kinematics, Dynamics',
        'icon': 'precision_manufacturing_rounded',
      },
    ),
  ];

  static const List<CurriculumMetadataModel> fallbackHigherEdLevels = [
    CurriculumMetadataModel(
      id: 'fb-level-1',
      category: 'higher_ed_level',
      key: 'bsc',
      displayName: "Bachelor's Degree (B.Sc / B.A)",
      metadata: {
        'code': 'bsc',
        'icon': 'history_edu_rounded',
        'subtitle': 'Undergraduate Degree Program',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-level-2',
      category: 'higher_ed_level',
      key: 'msc',
      displayName: "Master's Degree (M.Sc / M.A)",
      metadata: {
        'code': 'msc',
        'icon': 'workspace_premium_rounded',
        'subtitle': 'Postgraduate Master Program',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-level-3',
      category: 'higher_ed_level',
      key: 'phd',
      displayName: 'Doctorate Degree (Ph.D)',
      metadata: {
        'code': 'phd',
        'icon': 'psychology_alt_rounded',
        'subtitle': 'Doctoral Research Fellowship',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-level-4',
      category: 'higher_ed_level',
      key: 'ond',
      displayName: 'Ordinary National Diploma (OND)',
      metadata: {
        'code': 'ond',
        'icon': 'menu_book_rounded',
        'subtitle': 'Polytechnic 2-Year Program',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-level-5',
      category: 'higher_ed_level',
      key: 'hnd',
      displayName: 'Higher National Diploma (HND)',
      metadata: {
        'code': 'hnd',
        'icon': 'auto_stories_rounded',
        'subtitle': 'Advanced Polytechnic Program',
      },
    ),
  ];

  static const List<CurriculumMetadataModel> fallbackStudyGoals = [
    CurriculumMetadataModel(
      id: 'fb-goal-1',
      category: 'study_goal',
      key: 'thesis',
      displayName: 'Thesis & Research Paper Mastery',
      metadata: {
        'subtitle':
            'Literature citations, methodology synthesis, paper drafting',
        'icon': 'article_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-goal-2',
      category: 'study_goal',
      key: 'case_law',
      displayName: 'Legal Case Briefs & Jurisprudence',
      metadata: {
        'subtitle':
            'Case briefs, statute analysis, essay argument structure',
        'icon': 'gavel_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-goal-3',
      category: 'study_goal',
      key: 'socratic',
      displayName: 'Socratic Problem Solving & Logic',
      metadata: {
        'subtitle':
            'Interactive step-by-step problem solving without spoilers',
        'icon': 'psychology_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-goal-4',
      category: 'study_goal',
      key: 'spaced_rep',
      displayName: 'Spaced Repetition (SM-2) Flashcards',
      metadata: {
        'subtitle': 'Automated SM-2 review scheduling for lecture decks',
        'icon': 'schedule_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-goal-5',
      category: 'study_goal',
      key: 'mock_exams',
      displayName: 'Timed Mock Exams & Simulation',
      metadata: {
        'subtitle': 'Timed exam simulation calibrated to course syllabi',
        'icon': 'timer_outlined',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-goal-6',
      category: 'study_goal',
      key: 'essay_prep',
      displayName: 'Structured Essay & Argument Outlining',
      metadata: {
        'subtitle':
            'Structured essay outlines, argument mapping, citation help',
        'icon': 'edit_note_rounded',
      },
    ),
  ];

  static List<CurriculumMetadataModel> get fallbackHighSchoolSubjects =>
      kCuratedSubjectsCatalog.map((item) {
        return CurriculumMetadataModel(
          id: 'sub-${item.code.toLowerCase()}',
          category: 'high_school_subject',
          key: item.code.toLowerCase(),
          displayName: item.title,
          metadata: {
            'track': item.stream.toLowerCase(),
            'subtitle': item.description,
            'icon': item.icon,
            'code': item.code,
            'color': item.colorHex,
          },
        );
      }).toList();
}
