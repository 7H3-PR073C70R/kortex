import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/di/locator.dart';
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
      final response = await _dio.get<dynamic>(endpoint);
      final rawList = response.data is List
          ? response.data as List<dynamic>
          : <dynamic>[];

      if (rawList.isNotEmpty) {
        return rawList
            .map(
              (item) => CurriculumMetadataModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
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
      final response = await _dio.get<dynamic>(endpoint);
      final rawList = response.data is List
          ? response.data as List<dynamic>
          : <dynamic>[];

      if (rawList.isNotEmpty) {
        return rawList
            .map(
              (item) => CurriculumMetadataModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
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

  static const List<CurriculumMetadataModel> fallbackHighSchoolSubjects = [
    CurriculumMetadataModel(
      id: 'fb-sub-1',
      category: 'high_school_subject',
      key: 'core_math',
      displayName: 'General Mathematics (Core)',
      metadata: {
        'track': 'core',
        'subtitle': 'Algebra, Geometry, Trigonometry, Statistics',
        'icon': 'calculate_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-2',
      category: 'high_school_subject',
      key: 'core_english',
      displayName: 'English Language',
      metadata: {
        'track': 'core',
        'subtitle':
            'Comprehension, Grammar, Essay Writing, Oral English',
        'icon': 'spellcheck_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-3',
      category: 'high_school_subject',
      key: 'science_physics',
      displayName: 'Physics',
      metadata: {
        'track': 'science',
        'subtitle':
            'Mechanics, Optics, Waves, Electromagnetism, Modern Physics',
        'icon': 'flash_on_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-4',
      category: 'high_school_subject',
      key: 'science_chemistry',
      displayName: 'Chemistry',
      metadata: {
        'track': 'science',
        'subtitle':
            'Inorganic, Organic Reactions, Stoichiometry, Electrolysis',
        'icon': 'science_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-5',
      category: 'high_school_subject',
      key: 'science_biology',
      displayName: 'Biology',
      metadata: {
        'track': 'science',
        'subtitle': 'Cell Structure, Genetics, Ecology, Human Physiology',
        'icon': 'biotech_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-6',
      category: 'high_school_subject',
      key: 'science_further_math',
      displayName: 'Further Mathematics',
      metadata: {
        'track': 'science',
        'subtitle': 'Calculus, Vectors, Matrices, Complex Numbers',
        'icon': 'functions_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-7',
      category: 'high_school_subject',
      key: 'comm_accounting',
      displayName: 'Financial Accounting',
      metadata: {
        'track': 'commercial',
        'subtitle':
            'Final Accounts, Ledgers, Trial Balance, Ratio Analysis',
        'icon': 'account_balance_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-8',
      category: 'high_school_subject',
      key: 'comm_economics',
      displayName: 'Economics',
      metadata: {
        'track': 'commercial',
        'subtitle':
            'Micro & Macro Economics, Demand & Supply, Trade Theory',
        'icon': 'trending_up_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-9',
      category: 'high_school_subject',
      key: 'comm_commerce',
      displayName: 'Commerce',
      metadata: {
        'track': 'commercial',
        'subtitle':
            'Trade, Banking, Insurance, Transport, Warehousing',
        'icon': 'store_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-10',
      category: 'high_school_subject',
      key: 'arts_literature',
      displayName: 'Literature in English',
      metadata: {
        'track': 'arts',
        'subtitle':
            'Prose, Poetry, Drama — Set Texts & Critical Analysis',
        'icon': 'menu_book_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-11',
      category: 'high_school_subject',
      key: 'arts_government',
      displayName: 'Government',
      metadata: {
        'track': 'arts',
        'subtitle':
            'Constitutions, Political Systems, Electoral Processes',
        'icon': 'account_balance_wallet_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-12',
      category: 'high_school_subject',
      key: 'arts_history',
      displayName: 'History',
      metadata: {
        'track': 'arts',
        'subtitle':
            'West African, Nigerian & World History, Colonialism',
        'icon': 'history_edu_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-13',
      category: 'high_school_subject',
      key: 'arts_crk',
      displayName: 'Christian Religious Studies',
      metadata: {
        'track': 'arts',
        'subtitle':
            'Old & New Testament Studies, Christian Ethics, Church History',
        'icon': 'church_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-14',
      category: 'high_school_subject',
      key: 'arts_irk',
      displayName: 'Islamic Studies',
      metadata: {
        'track': 'arts',
        'subtitle':
            'Tawhid, Fiqh, Quranic Exegesis, Hadith Literature',
        'icon': 'auto_stories_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-15',
      category: 'high_school_subject',
      key: 'arts_geography',
      displayName: 'Geography',
      metadata: {
        'track': 'arts',
        'subtitle':
            'Physical Geography, Map Reading, Settlement & Resources',
        'icon': 'map_rounded',
      },
    ),
    CurriculumMetadataModel(
      id: 'fb-sub-16',
      category: 'high_school_subject',
      key: 'arts_civic',
      displayName: 'Civic Education',
      metadata: {
        'track': 'arts',
        'subtitle':
            'Human Rights, Rule of Law, Democratic Values, National Values',
        'icon': 'supervised_user_circle_rounded',
      },
    ),
  ];
}
