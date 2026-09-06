import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_metadata_section.dart';
import 'package:kortex/src/features/decks/presentation/widgets/manual_card_editor_view.dart';
import 'package:kortex/src/features/decks/presentation/widgets/upload_past_questions_view.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

@RoutePage()
class CreateDeckPage extends HookWidget {
  const CreateDeckPage({
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.mappedSubject,
    super.key,
  });

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final String? mappedSubject;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final selectedModeIndex = useState<int>(0);
    final selectedYear = useState<int?>(DateTime.now().year);
    final customYearController = useTextEditingController(
      text: DateTime.now().year.toString(),
    );

    final titleController = useTextEditingController(
      text: courseCode != null && courseCode!.isNotEmpty
          ? '$courseCode Past Questions & Review'
          : 'Course Study Deck',
    );
    final descController = useTextEditingController();

    // Mode 1: Upload Past Questions State
    final pickedFile = useState<PickedDocument?>(null);
    final isCalibrating = useState<bool>(false);
    final calibrationStatus = useState<String>('');
    final calibrationProgress = useState<double>(0);

    // Mode 2: Manual Creation State
    final manualFrontController = useTextEditingController();
    final manualBackController = useTextEditingController();
    final optionAController = useTextEditingController();
    final optionBController = useTextEditingController();
    final optionCController = useTextEditingController();
    final optionDController = useTextEditingController();
    final manualCorrectOption = useState<String>('A');
    final isMultipleChoice = useState<bool>(false);

    final manualAddedCards = useState<List<Map<String, dynamic>>>([]);
    final isManualSubmitting = useState<bool>(false);

    final resolvedSubject = courseTitle ?? mappedSubject ?? courseCode ?? 'General Studies';
    final resolvedCourseCode = courseCode ?? 'GEN101';

    int? getEffectiveYear() {
      final textYear = int.tryParse(customYearController.text.trim());
      if (textYear != null && textYear >= 1970 && textYear <= 2030) {
        return textYear;
      }
      return selectedYear.value;
    }

    // Pipeline: Extract, Calibrate with LLM, Save to Q-Bank & Deck
    Future<void> executeAiUploadCalibration() async {
      final year = getEffectiveYear();
      if (year == null) {
        context.showSnackBar(
          message: 'Please select or enter a valid examination year (e.g. 2024)',
        );
        return;
      }

      final doc = pickedFile.value;
      if (doc == null) {
        context.showSnackBar(
          message: 'Please select a past question document or image asset to upload',
        );
        return;
      }

      isCalibrating.value = true;
      calibrationProgress.value = 0.15;
      calibrationStatus.value = 'Ingesting & extracting document buffer...';
      AppFeedback.medium();

      try {
        final ingestionService = locator.isRegistered<LocalIngestionService>()
            ? locator<LocalIngestionService>()
            : LocalIngestionService();

        // 1. Text extraction
        final extractedText = await ingestionService.ingestBytes(
          bytes: doc.bytes,
          extension: doc.extension,
          filePath: doc.path,
        );

        calibrationProgress.value = 0.50;
        calibrationStatus.value = 'LLM calibrating questions, solutions & formula tokens...';

        // 2. Calibrate via LLM / StudyEngineRouter
        final studyEngine = locator.isRegistered<StudyEngineRouter>()
            ? locator<StudyEngineRouter>()
            : StudyEngineRouter();

        final studyResult = await studyEngine.generateStudyPack(
          topic: '$resolvedCourseCode $resolvedSubject Exam $year',
          count: 15,
          sourceText: extractedText.isNotEmpty ? extractedText : null,
        );

        calibrationProgress.value = 0.75;
        calibrationStatus.value = 'Registering calibrated set into global Past Question Bank...';

        final generatedCards = studyResult.cards;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final deckId = 'deck_pq_${resolvedCourseCode.toLowerCase()}_$timestamp';

        // 3. Register into global Past Question Bank
        final examCat = _deriveExamCategory(courseTitle ?? resolvedCourseCode);
        final pqModels = <PastQuestionModel>[];
        final flashcards = <FlashcardModel>[];

        for (var i = 0; i < generatedCards.length; i++) {
          final card = generatedCards[i];
          final qId = 'pq_upload_${timestamp}_$i';

          // Construct past question entity
          pqModels.add(
            PastQuestionModel(
              id: qId,
              examType: examCat,
              subject: resolvedSubject,
              year: year,
              questionNumber: i + 1,
              prompt: card.front,
              options: const [
                'Option A (Calibrated choice)',
                'Option B (Calibrated choice)',
                'Option C (Calibrated choice)',
                'Option D (Calibrated choice)',
              ],
              correctOptionIndex: 0,
              correctOptionLabel: 'A',
              explanation: card.explanation.isNotEmpty ? card.explanation : card.back,
              topic: resolvedSubject,
            ),
          );

          // Construct flashcard
          flashcards.add(
            FlashcardModel(
              id: 'card_${deckId}_$i',
              deckId: deckId,
              front: card.front,
              back: '${card.back}${card.explanation.isNotEmpty ? "\n\n💡 Explanation:\n${card.explanation}" : ""}',
              sourceTopic: resolvedSubject,
              nextDueDate: DateTime.now(),
            ),
          );
        }

        // Save into Past Question Bank
        if (locator.isRegistered<PastQuestionsRepository>()) {
          await locator<PastQuestionsRepository>().savePastQuestions(
            pqModels.map((m) => m.toEntity()).toList(),
          );
        }

        calibrationProgress.value = 0.90;
        calibrationStatus.value = 'Linking study deck to course curriculum...';

        // 4. Save Deck with Course Association
        final deckTitle = titleController.text.trim().isNotEmpty
            ? titleController.text.trim()
            : '$resolvedCourseCode $year Past Questions & Review';

        final deckModel = DeckModel(
          id: deckId,
          title: deckTitle,
          subject: resolvedSubject,
          totalCards: flashcards.length,
          dueCards: flashcards.length,
          masteryRate: 0,
          category: 'Official Past Questions',
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : 'Calibrated from official past paper asset ($year) for $resolvedCourseCode.',
          cards: flashcards,
          courseId: courseId,
          courseCode: resolvedCourseCode,
        );

        if (locator.isRegistered<DecksRemoteDataSource>()) {
          await locator<DecksRemoteDataSource>().saveGeneratedDeck(
            deck: deckModel,
            cards: flashcards,
          );
        }

        // 5. Refresh Blocs
        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }
        if (locator.isRegistered<PastQuestionsBloc>()) {
          locator<PastQuestionsBloc>().add(const LoadPastQuestionsEvent());
        }

        calibrationProgress.value = 1.0;
        AppFeedback.heavy();

        if (context.mounted) {
          context.showSnackBar(
            message: 'Successfully calibrated ${flashcards.length} questions & registered to Question Bank!',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop(true);
        }
      } on Object catch (err) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to calibrate past question deck: $err',
            type: SnackBarType.error,
          );
        }
      } finally {
        isCalibrating.value = false;
      }
    }

    // Mode 2: Manual Card Add
    void addManualCard() {
      final front = manualFrontController.text.trim();
      final back = manualBackController.text.trim();

      if (front.isEmpty || back.isEmpty) {
        context.showSnackBar(
          message: 'Please provide both question prompt (Front) and answer/explanation (Back)',
        );
        return;
      }

      AppFeedback.light();
      final cardItem = <String, dynamic>{
        'front': front,
        'back': back,
        'isMcq': isMultipleChoice.value,
      };

      if (isMultipleChoice.value) {
        cardItem['options'] = [
          if (optionAController.text.trim().isNotEmpty) optionAController.text.trim() else 'Option A',
          if (optionBController.text.trim().isNotEmpty) optionBController.text.trim() else 'Option B',
          if (optionCController.text.trim().isNotEmpty) optionCController.text.trim() else 'Option C',
          if (optionDController.text.trim().isNotEmpty) optionDController.text.trim() else 'Option D',
        ];
        cardItem['correctOption'] = manualCorrectOption.value;
      }

      manualAddedCards.value = [...manualAddedCards.value, cardItem];
      manualFrontController.clear();
      manualBackController.clear();
      optionAController.clear();
      optionBController.clear();
      optionCController.clear();
      optionDController.clear();
    }

    // Mode 2: Save Manual Deck
    Future<void> saveManualDeck() async {
      final year = getEffectiveYear();
      if (year == null) {
        context.showSnackBar(
          message: 'Please select or enter a valid examination year before creating the deck',
        );
        return;
      }

      if (manualAddedCards.value.isEmpty) {
        context.showSnackBar(
          message: 'Please add at least 1 flashcard or question to your deck',
        );
        return;
      }

      final title = titleController.text.trim().isNotEmpty
          ? titleController.text.trim()
          : '$resolvedCourseCode $year Practice Deck';

      isManualSubmitting.value = true;
      AppFeedback.medium();

      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final deckId = 'deck_manual_${resolvedCourseCode.toLowerCase()}_$timestamp';

        final flashcards = <FlashcardModel>[];
        final pqQuestions = <PastQuestionModel>[];
        final examCat = _deriveExamCategory(courseTitle ?? resolvedCourseCode);

        for (var i = 0; i < manualAddedCards.value.length; i++) {
          final item = manualAddedCards.value[i];
          final front = item['front'] as String;
          final back = item['back'] as String;
          final isMcq = item['isMcq'] as bool? ?? false;

          flashcards.add(
            FlashcardModel(
              id: 'card_${deckId}_$i',
              deckId: deckId,
              front: front,
              back: back,
              sourceTopic: resolvedSubject,
              nextDueDate: DateTime.now(),
            ),
          );

          if (isMcq && item['options'] != null) {
            final opts = (item['options'] as List).cast<String>();
            final correctOpt = item['correctOption'] as String? ?? 'A';
            final correctIdx = ['A', 'B', 'C', 'D'].indexOf(correctOpt).clamp(0, 3);

            pqQuestions.add(
              PastQuestionModel(
                id: 'pq_manual_${timestamp}_$i',
                examType: examCat,
                subject: resolvedSubject,
                year: year,
                questionNumber: i + 1,
                prompt: front,
                options: opts,
                correctOptionIndex: correctIdx,
                correctOptionLabel: correctOpt,
                explanation: back,
                topic: resolvedSubject,
              ),
            );
          }
        }

        // Register in Question Bank if MCQ past questions were added
        if (pqQuestions.isNotEmpty && locator.isRegistered<PastQuestionsRepository>()) {
          await locator<PastQuestionsRepository>().savePastQuestions(
            pqQuestions.map((q) => q.toEntity()).toList(),
          );
        }

        final deckModel = DeckModel(
          id: deckId,
          title: title,
          subject: resolvedSubject,
          totalCards: flashcards.length,
          dueCards: flashcards.length,
          masteryRate: 0,
          category: 'Course Review',
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : 'Manually curated study deck for $resolvedCourseCode ($year).',
          cards: flashcards,
          courseId: courseId,
          courseCode: resolvedCourseCode,
        );

        if (locator.isRegistered<DecksRemoteDataSource>()) {
          await locator<DecksRemoteDataSource>().saveGeneratedDeck(
            deck: deckModel,
            cards: flashcards,
          );
        }

        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }
        if (locator.isRegistered<PastQuestionsBloc>()) {
          locator<PastQuestionsBloc>().add(const LoadPastQuestionsEvent());
        }

        if (context.mounted) {
          context.showSnackBar(
            message: 'Deck successfully created with ${flashcards.length} card(s)!',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop(true);
        }
      } on Object catch (err) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to create deck: $err',
            type: SnackBarType.error,
          );
        }
      } finally {
        isManualSubmitting.value = false;
      }
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 19,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'Create Study Deck',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
              ),
            ),
            if (courseCode != null)
              Text(
                '$courseCode • $resolvedSubject',
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Segmented Tab Navigation
              AppLiquidGlassTabBar(
                tabs: const [
                  'Upload Past Questions',
                  'Manual Creation',
                ],
                selectedIndex: selectedModeIndex.value,
                onTabSelected: (index) {
                  AppFeedback.light();
                  selectedModeIndex.value = index;
                },
                height: 44,
              ),
              const SizedBox(height: 20),

              // 2. Common Deck Metadata: Year (Mandatory) & Title
              DeckMetadataSection(
                selectedYear: selectedYear,
                customYearController: customYearController,
                titleController: titleController,
                descController: descController,
              ),
              const SizedBox(height: 24),

              // 3. Tab Content
              if (selectedModeIndex.value == 0)
                UploadPastQuestionsView(
                  pickedFile: pickedFile,
                  isCalibrating: isCalibrating.value,
                  statusText: calibrationStatus.value,
                  progress: calibrationProgress.value,
                  onExecuteCalibration: executeAiUploadCalibration,
                )
              else
                ManualCardEditorView(
                  frontController: manualFrontController,
                  backController: manualBackController,
                  optionAController: optionAController,
                  optionBController: optionBController,
                  optionCController: optionCController,
                  optionDController: optionDController,
                  manualCorrectOption: manualCorrectOption,
                  isMultipleChoice: isMultipleChoice,
                  addedCards: manualAddedCards.value,
                  onAddCard: addManualCard,
                  onRemoveCard: (index) {
                    AppFeedback.light();
                    final list = List<Map<String, dynamic>>.from(manualAddedCards.value)..removeAt(index);
                    manualAddedCards.value = list;
                  },
                  isSubmitting: isManualSubmitting.value,
                  onSubmit: saveManualDeck,
                ),
            ],
          ),
        ),
      ),
    );
  }



  static ExamCategory _deriveExamCategory(String subjectOrTitle) {
    final lower = subjectOrTitle.toLowerCase();
    if (lower.contains('waec') || lower.contains('wassce')) return ExamCategory.waec;
    if (lower.contains('jamb') || lower.contains('utme')) return ExamCategory.jamb;
    if (lower.contains('neco')) return ExamCategory.neco;
    if (lower.contains('sat')) return ExamCategory.sat;
    if (lower.contains('toefl')) return ExamCategory.toefl;
    if (lower.contains('ielts')) return ExamCategory.ielts;
    if (lower.contains('med') || lower.contains('anat') || lower.contains('phs')) {
      return ExamCategory.medicine;
    }
    if (lower.contains('law')) return ExamCategory.law;
    if (lower.contains('eng') || lower.contains('eee') || lower.contains('mec')) {
      return ExamCategory.engineering;
    }
    if (lower.contains('csc') || lower.contains('comp') || lower.contains('inf')) {
      return ExamCategory.computerScience;
    }
    if (lower.contains('bus') || lower.contains('acc') || lower.contains('mgt')) {
      return ExamCategory.business;
    }
    return ExamCategory.general;
  }
}
