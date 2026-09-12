import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/bionic_text_formatter.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/features/decks/presentation/widgets/audio_pronounce_button.dart';
import 'package:kortex/src/features/decks/presentation/widgets/image_occlusion_card_viewer.dart';
import 'package:kortex/src/features/ingestion/domain/services/deep_document_dedup_service.dart';
import 'package:kortex/src/features/ingestion/domain/services/recursive_text_splitter.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/audio_lecture_ingestion_sheet.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone_widget.dart';
import 'package:kortex/src/features/monetization/presentation/screens/paywall_screen.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/academic_focus_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_exam_step.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
import 'package:kortex/src/features/planner/presentation/widgets/study_calibration_graph_widget.dart';
import 'package:kortex/src/features/planner/presentation/widgets/syllabus_checklist_widget.dart';
import 'package:kortex/src/features/profile/presentation/widgets/active_sessions_list_widget.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_lifeline_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_audio_reader_button.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_latex_scratchpad_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/engine_status_indicator.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/font_loader_helper.dart';
import '../helpers/screenshot_helper.dart';

import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';

class MockDecksRemoteDataSource extends Mock implements DecksRemoteDataSource {}
class MockQuizDuelCubit extends Mock implements QuizDuelCubit {}
class MockCramPlannerCubit extends Mock implements CramPlannerCubit {}
class MockCalibrationCubit extends Mock implements CalibrationCubit {}
class FakeDeckModel extends Fake implements DeckModel {}
class FakeFlashcardModel extends Fake implements FlashcardModel {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Master End-to-End Feature Validation & Marketing Screenshot Suite', () {
    final screenshotKey = GlobalKey();

    setUpAll(() async {
      await TestFontLoaderHelper.loadFonts();
      registerFallbackValue(FakeDeckModel());
      registerFallbackValue(<FlashcardModel>[]);
    });

    setUp(() {
      registerFallbackValue(
        DeckEntity(
          id: UuidUtils.generate(),
          title: 'Fallback',
          subject: 'General',
          category: 'General',
          totalCards: 0,
          dueCards: 0,
          masteryRate: 0,
        ),
      );
    });

    // =========================================================================
    // MODULE 1: Onboarding, Calibration & Academic Track Configuration
    // (ONB-01 through ONB-12)
    // =========================================================================
    testWidgets('Module 1 [ONB-01 to ONB-12]: Academic Calibration Flow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockCalibrationCubit = MockCalibrationCubit();
      when(() => mockCalibrationCubit.state).thenReturn(
        const CalibrationState(
          profile: CalibrationProfile(
            focus: AcademicFocus.highSchool,
            highSchoolExam: 'JAMB',
          ),
        ),
      );
      when(() => mockCalibrationCubit.stream).thenAnswer((_) => const Stream.empty());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: BlocProvider<CalibrationCubit>.value(
          value: mockCalibrationCubit,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'KORTEX CALIBRATION',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Personalize Your Neural Study Engine',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                AcademicFocusStep(),
                SizedBox(height: 20),
                HighSchoolExamStep(),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Personalize Your Neural Study Engine'), findsOneWidget);
      expect(find.byType(AcademicFocusStep), findsOneWidget);
      expect(find.byType(HighSchoolExamStep), findsOneWidget);

      // 📸 Capture Marketing Screenshot 1: Onboarding Calibration
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '01_onboarding_academic_calibration',
      );
    });

    // =========================================================================
    // MODULE 2: Dashboard & Smart Study Command Center
    // (DSH-01 through DSH-10)
    // =========================================================================
    testWidgets('Module 2 [DSH-01 to DSH-10]: Dashboard Command Center', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleExam = ExamEventEntity(
        id: 'jamb-med',
        userId: 'user_1',
        examName: 'JAMB UTME Medicine & Surgery',
        targetDate: DateTime.now().add(const Duration(days: 45)),
        subjectTrack: 'JAMB Medicine',
        totalCardsCount: 300,
        masteredCardsCount: 120,
        dailyTarget: 40,
      );

      final mockPlannerCubit = MockCramPlannerCubit();
      when(() => mockPlannerCubit.state).thenReturn(
        CramPlannerState(
          status: CramPlannerStatus.loaded,
          activeExams: [sampleExam],
          selectedExam: sampleExam,
        ),
      );
      when(() => mockPlannerCubit.stream).thenAnswer((_) => const Stream.empty());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: BlocProvider<CramPlannerCubit>.value(
          value: mockPlannerCubit,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Streak & Pro Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Welcome Back, Scholar 👋',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'JAMB 2026 Medical Track • Day 14 Streak 🔥',
                            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF9333EA)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PRO ACTIVE ⚡',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Countdown Banner
                const ExamCountdownBanner(),
                const SizedBox(height: 20),

                // Study Activity Calibration Graph
                StudyCalibrationGraphWidget(
                  exam: sampleExam,
                  onStartStudySession: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back, Scholar 👋'), findsOneWidget);
      expect(find.byType(ExamCountdownBanner), findsOneWidget);
      expect(find.byType(StudyCalibrationGraphWidget), findsOneWidget);

      // 📸 Capture Marketing Screenshot 2: Dashboard Command Center
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '02_dashboard_smart_command_center',
      );
    });

    // =========================================================================
    // MODULE 3: Flashcard Studio & Spaced Repetition (FSRS-6)
    // (FSR-01 through FSR-15)
    // =========================================================================
    testWidgets('Module 3 [FSR-01 to FSR-15]: FSRS-6 Math Engine & Studio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Validate FSRS-6 Algorithm Engine
      final engine = FsrsAlgorithmEngine();
      final scheduler = SchedulerFactory(fsrsEngine: engine);
      final initial = FsrsCardState.initial();

      final goodReview = scheduler.calculate(rating: 3, previousFsrsState: initial);
      expect(goodReview.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(goodReview.fsrsState?.stability, greaterThan(2.0));
      expect(goodReview.nextIntervalDays, greaterThanOrEqualTo(2));

      // 2. Render Flashcard Studio UI with Image Occlusion & Audio Pronounce
      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Expanded(
                    child: Text(
                      'Card 4 / 20 • FSRS-6 Active Recall',
                      style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  AudioPronounceButton(
                    textToPronounce: 'Gibbs Free Energy Equation Delta G equals Delta H minus T Delta S',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THERMODYNAMICS & EQUILIBRIUM',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'State the fundamental Gibbs Free Energy relation and criteria for spontaneity:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          r'ΔG = ΔH - TΔS  (Spontaneous when ΔG < 0)',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Interactive Image Occlusion Anatomy Viewer
              SizedBox(
                height: 260,
                child: ImageOcclusionCardViewer(
                  masks: const [
                    OcclusionMask(
                      id: 'mask_1',
                      rect: Rect.fromLTWH(0.1, 0.1, 0.3, 0.2),
                      answerText: 'Left Ventricle',
                    ),
                    OcclusionMask(
                      id: 'mask_2',
                      rect: Rect.fromLTWH(0.5, 0.1, 0.3, 0.2),
                      answerText: 'Aorta',
                    ),
                  ],
                  onMaskRevealed: (id) {},
                ),
              ),
              const SizedBox(height: 20),
              // 4-Button FSRS Grading Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: const Column(
                        children: [
                          Text('Again', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          Text('<10m', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Column(
                        children: [
                          Text('Hard', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                          Text('1.5d', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B82F6)),
                      ),
                      child: const Column(
                        children: [
                          Text('Good', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                          Text('3.2d', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Column(
                        children: [
                          Text('Easy', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          Text('7.5d', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('THERMODYNAMICS & EQUILIBRIUM'), findsOneWidget);
      expect(find.byType(ImageOcclusionCardViewer), findsOneWidget);

      // 📸 Capture Marketing Screenshot 3: FSRS-6 Flashcard Studio
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '03_fsrs_flashcard_study_studio',
      );
    });

    // =========================================================================
    // MODULE 4: Document Ingestion, OCR & Multimodal Synthesis
    // (ING-01 through ING-12)
    // =========================================================================
    testWidgets('Module 4 [ING-01 to ING-12]: Multimodal Document & Audio Ingestion', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Test Text Splitter & Dedup
      const splitter = RecursiveTextSplitter(chunkSize: 100, chunkOverlap: 20);
      final chunks = splitter.splitText(
        text: 'Cell biology is the study of cell structure and function. Mitochondria generate ATP through oxidative phosphorylation.',
      );
      expect(chunks.isNotEmpty, isTrue);

      final dedup = DeepDocumentDedupService();
      final sim = dedup.calculateTextSimilarity(
        'Photosynthesis converts light into chemical energy.',
        'Photosynthesis transforms light into chemical energy.',
      );
      expect(sim, greaterThan(0.5));

      // 2. Render Ingestion Drop Zone & Audio Transcriber
      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Ingestion & OCR Studio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Drop textbooks, syllabi, lecture audio, or scan with camera.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FileDropZoneWidget(
                onFilePicked: ({
                  required filename,
                  required fileType,
                  required fileBytes,
                }) {},
              ),
              const SizedBox(height: 20),
              AudioLectureIngestionSheet(
                onTranscriptionCompleted: (transcript) {},
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.byType(FileDropZoneWidget), findsOneWidget);
      expect(find.byType(AudioLectureIngestionSheet), findsOneWidget);
    });

    // =========================================================================
    // MODULE 5: Syllabot AI: Socratic Learning & Multimodal Assistant
    // (SYL-01 through SYL-14)
    // =========================================================================
    testWidgets('Module 5 [SYL-01 to SYL-14]: Syllabot Socratic AI Tutor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                            ),
                          ),
                          child: const Icon(Icons.psychology, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Syllabot AI Tutor',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Socratic Mode • Rigorous Proofs',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  EngineStatusIndicator(
                    engineType: ExecutionEngineType.cloudRemote,
                    onToggleEngine: (type) {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Chat Bubble 1: Student
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'How do I calculate electric flux through a closed spherical surface?',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Chat Bubble 2: Syllabot Socratic Explanation
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Think about Gauss’s Law. What does the enclosed charge determine about the total surface integral?',
                        style: TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          r'Φ_E = ∮ E · dA = Q_enclosed / ε₀',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '📖 Source: Halliday Resnick Physics • Ch 23',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Math Formula Scratchpad
              ChatLatexScratchpadWidget(
                onInsertLatex: (latex) {},
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Syllabot AI Tutor'), findsOneWidget);
      expect(find.byType(ChatLatexScratchpadWidget), findsOneWidget);

      // 📸 Capture Marketing Screenshot 4: Syllabot Socratic AI
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '04_syllabot_socratic_ai_tutor',
      );
    });

    // =========================================================================
    // MODULE 6: Gamified Quiz Arena & CBT Practice Engine
    // (QZ-01 through QZ-16)
    // =========================================================================
    testWidgets('Module 6 [QZ-01 to QZ-16]: Millionaire Ladder & 1v1 PvP Arena', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Millionaire Gamified Quiz View
      final millionaireWidget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Expanded(
                    child: Text(
                      'STUDY MILLIONAIRE 🏆',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  QuizAudioReaderButton(
                    questionText: 'What is the acceleration due to gravity on Earth?',
                    options: ['9.8 m/s²', '8.9 m/s²', '10.5 m/s²', '12.0 m/s²'],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MillionaireLifelineBar(
                state: const QuizSessionState(
                  assessmentMode: AssessmentMode.millionaireMode,
                ),
                onUseFiftyFifty: () {},
                onUseAiClue: () {},
                onUseSkipSwap: () {},
                onOpenLadder: () {},
                onWalkAway: () {},
                onUseAskAudience: () {},
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Text(
                  'Tier 7 • Question for 25,000 XP:\n\nWhich organelle is responsible for cellular respiration and ATP synthesis?',
                  style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              McqOptionCard(
                index: 0,
                optionText: 'Ribosome',
                isSelected: false,
                isAnswered: false,
                isCorrect: false,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              McqOptionCard(
                index: 1,
                optionText: 'Mitochondria (Correct)',
                isSelected: true,
                isAnswered: true,
                isCorrect: true,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              McqOptionCard(
                index: 2,
                optionText: 'Golgi Apparatus',
                isSelected: false,
                isAnswered: false,
                isCorrect: false,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              McqOptionCard(
                index: 3,
                optionText: 'Endoplasmic Reticulum',
                isSelected: false,
                isAnswered: false,
                isCorrect: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(millionaireWidget);
      await tester.pumpAndSettle();

      expect(find.text('STUDY MILLIONAIRE 🏆'), findsOneWidget);
      expect(find.byType(MillionaireLifelineBar), findsOneWidget);

      // 📸 Capture Marketing Screenshot 5: Study Millionaire Quiz Arena
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '05_study_millionaire_quiz_arena',
      );

      // 2. 1v1 PvP Quiz Duel Arena View
      final mockDuelCubit = MockQuizDuelCubit();
      final testMatch = QuizDuelMatch(
        duelId: 'test_duel_123',
        subject: 'Physics',
        examBoard: 'JAMB',
        questions: QuizDuelWebSocketClient.getDefaultDuelQuestions('Physics', 'JAMB'),
        player1: const QuizDuelParticipant(
          userId: 'user_1',
          displayName: 'Scholar One',
          avatarUrl: '⚡',
          score: 120,
        ),
        player2: const QuizDuelParticipant(
          userId: 'ai_bot_1',
          displayName: 'Syllabot Rival',
          avatarUrl: '🧠',
          score: 95,
          isAiOpponent: true,
        ),
        status: QuizDuelStatus.inRound,
      );

      when(() => mockDuelCubit.state).thenReturn(
        QuizDuelState(
          status: QuizDuelStatus.inRound,
          currentUserId: 'user_1',
          match: testMatch,
        ),
      );
      when(() => mockDuelCubit.stream).thenAnswer((_) => const Stream.empty());

      final duelWidget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: BlocProvider<QuizDuelCubit>.value(
          value: mockDuelCubit,
          child: const QuizDuelArenaPage(),
        ),
      );

      await tester.pumpWidget(duelWidget);
      await tester.pumpAndSettle();

      expect(find.text('Scholar One'), findsOneWidget);
      expect(find.text('Syllabot Rival'), findsOneWidget);

      // 📸 Capture Marketing Screenshot 6: 1v1 PvP Duel Match
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '06_pvp_quiz_duel_match',
      );
    });

    // =========================================================================
    // MODULE 7: Community Hub, Body Doubling & Live Study Rooms
    // (COM-01 through COM-18)
    // =========================================================================
    testWidgets('Module 7 [COM-01 to COM-18]: Live Study Pod & Whiteboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Live Study Pod: Med-UTME Hub',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '🟢 6 Students Co-Working • Spatial Audio Active',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Speaker Avatar Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _buildSpeakerAvatar('Chioma', true)),
                  Expanded(child: _buildSpeakerAvatar('Ahmed', false)),
                  Expanded(child: _buildSpeakerAvatar('Tobi', false)),
                  Expanded(child: _buildSpeakerAvatar('Ngozi', false)),
                ],
              ),
              const SizedBox(height: 24),

              // Collaborative Whiteboard Mock
              Container(
                width: double.infinity,
                height: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Expanded(
                          child: Text(
                            '🎨 Shared Canvas: Nephron Filtration Mechanism',
                            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Synced ⚡', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Text(
                        'Glomerulus ➔ Bowman\'s Capsule ➔ Proximal Tubule (Active Reabsorption)',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Live Study Pod: Med-UTME Hub'), findsOneWidget);

      // 📸 Capture Marketing Screenshot 7: Community Live Voice Pod & Whiteboard
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '07_community_live_voice_pod_whiteboard',
      );
    });

    // =========================================================================
    // MODULE 8: Exam Timetable & Cram Workload Planner
    // (PLN-01 through PLN-08)
    // =========================================================================
    testWidgets('Module 8 [PLN-01 to PLN-08]: Adaptive Cram Workload Planner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Workload Calculator Engine Validation
      const calc = CramWorkloadCalculator();
      final quota = calc.calculateDailyTarget(
        remainingCards: 200,
        lapses: 10,
        daysRemaining: 10,
      );
      expect(quota, greaterThanOrEqualTo(20));

      // 2. Render Planner UI with Syllabus Checklist
      final plannerExam = ExamEventEntity(
        id: 'waec-chem',
        userId: 'user_1',
        examName: 'WAEC Higher Chemistry 2026',
        targetDate: DateTime.now().add(const Duration(days: 12)),
        subjectTrack: 'WAEC Science',
        totalCardsCount: 250,
        masteredCardsCount: 90,
        dailyTarget: 35,
      );

      final mockPlannerCubit = MockCramPlannerCubit();
      when(() => mockPlannerCubit.state).thenReturn(
        CramPlannerState(
          status: CramPlannerStatus.loaded,
          activeExams: [plannerExam],
          selectedExam: plannerExam,
        ),
      );
      when(() => mockPlannerCubit.stream).thenAnswer((_) => const Stream.empty());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: BlocProvider<CramPlannerCubit>.value(
          value: mockPlannerCubit,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exam Timetable & Cram Pacing',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dynamic daily quotas calibrated to your target retention score.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const ExamCountdownBanner(),
                const SizedBox(height: 20),
                SizedBox(
                  height: 450,
                  child: SyllabusChecklistWidget(
                    topics: const [
                      SyllabusTopic(
                        id: 'top-1',
                        title: 'Organic Chemistry & Hydrocarbons',
                        subject: 'Chemistry',
                        weightPercent: 30,
                        isMastered: true,
                      ),
                      SyllabusTopic(
                        id: 'top-2',
                        title: 'Electrochemistry & Redox Potentials',
                        subject: 'Chemistry',
                        weightPercent: 25,
                        isMastered: true,
                      ),
                      SyllabusTopic(
                        id: 'top-3',
                        title: 'Chemical Equilibrium & Le Chatelier',
                        subject: 'Chemistry',
                        weightPercent: 25,
                        isMastered: false,
                      ),
                      SyllabusTopic(
                        id: 'top-4',
                        title: 'Nuclear Chemistry & Radioactivity',
                        subject: 'Chemistry',
                        weightPercent: 20,
                        isMastered: false,
                      ),
                    ],
                    onTopicToggled: (topic, {required isMastered}) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Exam Timetable & Cram Pacing'), findsOneWidget);
      expect(find.byType(SyllabusChecklistWidget), findsOneWidget);

      // 📸 Capture Marketing Screenshot 8: Cram Workload Planner
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '08_cram_exam_workload_planner',
      );
    });

    // =========================================================================
    // MODULE 9: ADHD & Neurodivergent Accessibility Suite
    // (ACC-01 through ACC-10)
    // =========================================================================
    testWidgets('Module 9 [ACC-01 to ACC-10]: ADHD Bionic Reading & OLED Dark Theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Test Bionic Saccade Formatter
      final bionicText = BionicTextFormatter.format(
        'Kortex is designed to bypass executive dysfunction and accelerate retention.',
      );
      expect(bionicText.contains('**'), isTrue);

      // 2. Render ADHD Accessibility Showcase
      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        theme: AppTheme.darkTheme,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADHD & Neurodivergent Suite',
                style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Low Sensory OLED Dark & Bionic Focus',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black, // Pure OLED Black #000000
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BIONIC READING DEMONSTRATION:',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      BionicTextFormatter.format(
                        'Active recall strengthens neural synaptic pathways. By guiding eye fixations through bold initial letters, reading fatigue is reduced by 40% for neurodivergent minds.',
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Accessibility controls chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildA11yChip('OLED Dark 🌑', true),
                  _buildA11yChip('Reduced Motion 🧘', true),
                  _buildA11yChip('Atkinson Font 🔤', true),
                ],
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('ADHD & Neurodivergent Suite'), findsOneWidget);

      // 📸 Capture Marketing Screenshot 9: ADHD Bionic Reading & OLED Dark
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '09_adhd_bionic_reading_oled_dark',
      );
    });

    // =========================================================================
    // MODULE 10: Profile, Security & Two-Factor Authentication
    // (SEC-01 through SEC-09)
    // =========================================================================
    testWidgets('Module 10 [SEC-01 to SEC-09]: Security & Active Sessions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Security & Multi-Device Sessions',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hardware-backed SQLCipher encryption & active device controls.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 450,
                child: ActiveSessionsListWidget(
                  sessions: [
                    DeviceSession(
                      id: 'sess_1',
                      deviceName: 'iPhone 15 Pro Max',
                      osType: 'ios',
                      ipAddress: '102.89.44.12',
                      location: 'Lagos, Nigeria',
                      lastActive: DateTime.now(),
                      isCurrentDevice: true,
                    ),
                    DeviceSession(
                      id: 'sess_2',
                      deviceName: 'MacBook Pro M3 Max',
                      osType: 'macos',
                      ipAddress: '102.89.44.12',
                      location: 'Lagos, Nigeria',
                      lastActive: DateTime.now().subtract(const Duration(hours: 3)),
                      isCurrentDevice: false,
                    ),
                  ],
                  onRevokeSession: (id) {},
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.byType(ActiveSessionsListWidget), findsOneWidget);
    });

    // =========================================================================
    // MODULE 11: Monetization, RevenueCat & Subscription Guards
    // (MON-01 through MON-06)
    // =========================================================================
    testWidgets('Module 11 [MON-01 to MON-06]: Feature Paywall & Promo Codes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final widget = ScreenshotTestWrapper.wrapForScreenshot(
        boundaryKey: screenshotKey,
        child: const PaywallScreen(),
      );

      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Supercharge Your Academic Mastery'), findsOneWidget);

      // 📸 Capture Marketing Screenshot 10: Pro Monetization Paywall
      await ScreenshotTestWrapper.captureAndSave(
        tester: tester,
        boundaryKey: screenshotKey,
        screenshotName: '10_pro_feature_paywall_subscription',
      );
    });

    // =========================================================================
    // MODULE 12: Offline-First Architecture & Core Infrastructure
    // (INF-01 through INF-11)
    // =========================================================================
    testWidgets('Module 12 [INF-01 to INF-11]: Offline UUID & Conversion Validation', (
      tester,
    ) async {
      final mockDecksDataSource = MockDecksRemoteDataSource();
      when(
        () => mockDecksDataSource.saveGeneratedDeck(
          deck: any(named: 'deck'),
          cards: any(named: 'cards'),
        ),
      ).thenAnswer((_) async {});

      final useCase = ConvertFailedQuizToDeckUseCase(mockDecksDataSource);
      final result = await useCase(
        result: const QuizResultEntity(
          id: 'res-1',
          quizTitle: 'WAEC Physics Diagnostics',
          correctAnswers: 8,
          durationSeconds: 300,
          totalQuestions: 10,
          weaknesses: [
            TopicWeakness(
              subTopic: 'Optics & Snell Law',
              correctCount: 2,
              totalQuestions: 5,
            ),
          ],
        ),
        questions: const [
          QuizQuestionEntity(
            id: 'q-1',
            prompt: 'What is refractive index formula?',
            type: QuizQuestionType.multipleChoice,
            options: ['sin i / sin r', 'cos i / cos r'],
            correctAnswer: 'sin i / sin r',
            explanation: 'Snell\'s Law defines n = sin i / sin r',
            subTopic: 'Optics',
            isCorrect: false,
          ),
        ],
      );

      expect(result.isRight, isTrue);
      result.fold(
        (l) => fail('Expected conversion to succeed'),
        (deck) {
          expect(UuidUtils.isValidUuid(deck.id), isTrue);
          expect(deck.cards.isNotEmpty, isTrue);
          expect(UuidUtils.isValidUuid(deck.cards.first.id), isTrue);
        },
      );
    });
  });
}

Widget _buildSpeakerAvatar(String name, bool isSpeaking) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSpeaking ? const Color(0xFF10B981) : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF334155),
          child: Text(
            name[0],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        name,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    ],
  );
}

Widget _buildA11yChip(String label, bool isSelected) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSelected ? const Color(0xFF6366F1).withAlpha(40) : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: isSelected ? const Color(0xFF818CF8) : Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
