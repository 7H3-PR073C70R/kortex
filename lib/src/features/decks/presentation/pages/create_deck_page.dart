import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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
    final isDark = context.isDarkMode;

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

      if (pickedFile.value == null) {
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
        final doc = pickedFile.value!;
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
              _buildYearAndMetadataSection(
                context,
                selectedYear: selectedYear,
                customYearController: customYearController,
                titleController: titleController,
                descController: descController,
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // 3. Tab Content
              if (selectedModeIndex.value == 0)
                _buildUploadPastQuestionsRoute(
                  context,
                  pickedFile: pickedFile,
                  isCalibrating: isCalibrating.value,
                  statusText: calibrationStatus.value,
                  progress: calibrationProgress.value,
                  onExecuteCalibration: executeAiUploadCalibration,
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                )
              else
                _buildManualCreationRoute(
                  context,
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
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section: Mandatory Year & Deck Metadata
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildYearAndMetadataSection(
    BuildContext context, {
    required ValueNotifier<int?> selectedYear,
    required TextEditingController customYearController,
    required TextEditingController titleController,
    required TextEditingController descController,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    final quickYears = [2024, 2023, 2022, 2021, 2020, 2019];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(120)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Examination Year (Required)',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '*',
                style: typography.callout.bold.copyWith(
                  color: colors.error,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Calibrates standard questions to the exact testing year curriculum.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),

          // Year selection chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickYears.map((yr) {
              final isSelected = selectedYear.value == yr;
              return ShrinkableButton(
                onTap: () {
                  AppFeedback.light();
                  selectedYear.value = yr;
                  customYearController.text = yr.toString();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : (isDark ? colors.surfaceTertiary.withAlpha(80) : colors.surfaceSecondary),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : (isDark ? colors.surfaceBorderHighlight.withAlpha(40) : colors.surfaceBorder),
                    ),
                  ),
                  child: Text(
                    yr.toString(),
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.white : colors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Custom Year Input
          AppTextField(
            controller: customYearController,
            label: 'Or Enter Custom Year',
            hintText: 'e.g. 2018 or 2025',
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val.trim());
              if (parsed != null) {
                selectedYear.value = parsed;
              }
            },
          ),
          const SizedBox(height: 14),

          // Deck Title
          AppTextField(
            controller: titleController,
            label: 'Deck Title',
            hintText: 'e.g. MTH 101 Calculus Past Paper & Practice',
          ),
          const SizedBox(height: 10),

          // Deck Description (Optional)
          AppTextField(
            controller: descController,
            label: 'Description (Optional)',
            hintText: 'e.g. Verified official questions and step-by-step solutions',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mode 1: Upload Past Questions (Asset/PDF Route)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildUploadPastQuestionsRoute(
    BuildContext context, {
    required ValueNotifier<PickedDocument?> pickedFile,
    required bool isCalibrating,
    required String statusText,
    required double progress,
    required VoidCallback onExecuteCalibration,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Past Questions Asset',
          style: typography.callout.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Our AI engine will parse the document, extract question stems & options, calibrate verified answers, and register them into the global Question Bank.',
          style: typography.footnote.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),

        // Dropzone / File Picker Container
        ShrinkableButton(
          onTap: isCalibrating
              ? null
              : () async {
                  AppFeedback.light();
                  final doc = await FilePickerService().pickStudyDocument(
                    extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'pptx'],
                  );
                  if (doc != null) {
                    pickedFile.value = doc;
                  }
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(120)
                  : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: pickedFile.value != null
                    ? colors.primary
                    : (isDark ? colors.surfaceBorderHighlight.withAlpha(60) : colors.surfaceBorder),
                width: pickedFile.value != null ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 45 : 25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pickedFile.value != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (pickedFile.value == null) ...[
                  Text(
                    'Select PDF or Document Asset',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to browse PDF past papers, exam snapshots, or lecture notes (Max 50MB)',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ] else ...[
                  Text(
                    pickedFile.value!.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(pickedFile.value!.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB • Ready for AI calibration',
                    style: typography.footnote.regular.copyWith(
                      color: colors.success,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      AppFeedback.light();
                      pickedFile.value = null;
                    },
                    icon: Icon(Icons.close_rounded, size: 16, color: colors.error),
                    label: Text(
                      'Remove File',
                      style: typography.caption.bold.copyWith(
                        color: colors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Progress bar during calibration
        if (isCalibrating) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withAlpha(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colors.primary.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action Trigger Button
        AppButton(
          text: isCalibrating ? 'Calibrating via LLM...' : 'Extract, Calibrate & Generate Deck',
          isLoading: isCalibrating,
          onPressed: isCalibrating ? null : onExecuteCalibration,
          prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mode 2: Manual Creation Route
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildManualCreationRoute(
    BuildContext context, {
    required TextEditingController frontController,
    required TextEditingController backController,
    required TextEditingController optionAController,
    required TextEditingController optionBController,
    required TextEditingController optionCController,
    required TextEditingController optionDController,
    required ValueNotifier<String> manualCorrectOption,
    required ValueNotifier<bool> isMultipleChoice,
    required List<Map<String, dynamic>> addedCards,
    required VoidCallback onAddCard,
    required ValueChanged<int> onRemoveCard,
    required bool isSubmitting,
    required VoidCallback onSubmit,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add Flashcard / Question',
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 15,
              ),
            ),
            Row(
              children: [
                Text(
                  'Multiple Choice (MCQ)',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Switch.adaptive(
                  value: isMultipleChoice.value,
                  activeThumbColor: colors.primary,
                  onChanged: (val) {
                    AppFeedback.light();
                    isMultipleChoice.value = val;
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Front (Prompt / Question)
        AppTextField(
          controller: frontController,
          label: 'Question Prompt / Front',
          hintText: r'e.g. What is the derivative of \( f(x) = x^3 \)?',
          maxLines: 3,
        ),
        const SizedBox(height: 12),

        // Multiple Choice Options (If enabled)
        if (isMultipleChoice.value) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary.withAlpha(100) : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Options & Correct Answer',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(controller: optionAController, label: 'Option A', hintText: 'Option A text'),
                const SizedBox(height: 8),
                AppTextField(controller: optionBController, label: 'Option B', hintText: 'Option B text'),
                const SizedBox(height: 8),
                AppTextField(controller: optionCController, label: 'Option C', hintText: 'Option C text'),
                const SizedBox(height: 8),
                AppTextField(controller: optionDController, label: 'Option D', hintText: 'Option D text'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Correct Option:',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...['A', 'B', 'C', 'D'].map((opt) {
                      final isSelected = manualCorrectOption.value == opt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            manualCorrectOption.value = opt;
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? colors.primary : colors.surfaceTertiary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colors.primary : colors.surfaceBorder,
                              ),
                            ),
                            child: Text(
                              opt,
                              style: typography.caption.bold.copyWith(
                                color: isSelected ? colors.white : colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Back (Answer & Solution)
        AppTextField(
          controller: backController,
          label: 'Solution / Answer / Back',
          hintText: r'e.g. \( 3x^2 \). Power rule states d/dx[x^n] = n*x^(n-1).',
          maxLines: 3,
        ),
        const SizedBox(height: 12),

        // Add Card Button
        Align(
          alignment: Alignment.centerRight,
          child: ShrinkableButton(
            onTap: onAddCard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Add Card to Deck',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Added Cards Preview
        if (addedCards.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Added Cards (${addedCards.length})',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: addedCards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final card = addedCards[idx];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceSecondary.withAlpha(100) : colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LatexRichViewer(
                            text: card['front'] as String,
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LatexRichViewer(
                            text: card['back'] as String,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                      onPressed: () => onRemoveCard(idx),
                      tooltip: 'Remove Card',
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        // Submit Manual Deck Button
        AppButton(
          text: isSubmitting ? 'Creating Study Deck...' : 'Save Deck (${addedCards.length} Cards)',
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
          prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18),
        ),
      ],
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
