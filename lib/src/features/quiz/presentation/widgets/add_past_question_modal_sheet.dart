import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/services/past_question_ai_extractor_service.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class AddPastQuestionModalSheet extends HookWidget {
  const AddPastQuestionModalSheet({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.examCategory,
    this.pastQuestionsBloc,
    this.onAdded,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final ExamCategory examCategory;
  final PastQuestionsBloc? pastQuestionsBloc;
  final void Function(List<PastQuestionEntity>)? onAdded;

  static Future<bool?> show(
    BuildContext context, {
    String? courseId,
    String? courseCode,
    String? courseTitle,
    String? mappedSubject,
    String? defaultSubject,
    ExamCategory? examCategory,
    PastQuestionsBloc? pastQuestionsBloc,
    void Function(List<PastQuestionEntity>)? onAdded,
  }) {
    final effectiveSubject = mappedSubject ?? defaultSubject ?? 'General Studies';
    final effectiveCourseCode = courseCode ?? 'GEN101';
    final effectiveCourseId = courseId ?? 'course_gen';
    final effectiveCourseTitle = courseTitle ?? effectiveSubject;
    final effectiveExamCategory = examCategory ?? ExamCategory.waec;

    final bloc = pastQuestionsBloc ??
        (context.mounted
            ? (tryReadBloc<PastQuestionsBloc>(context) ??
                (locator.isRegistered<PastQuestionsBloc>()
                    ? locator<PastQuestionsBloc>()
                    : null))
            : null);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPastQuestionModalSheet(
        courseId: effectiveCourseId,
        courseCode: effectiveCourseCode,
        courseTitle: effectiveCourseTitle,
        mappedSubject: effectiveSubject,
        examCategory: effectiveExamCategory,
        pastQuestionsBloc: bloc,
        onAdded: onAdded,
      ),
    );
  }

  static T? tryReadBloc<T extends BlocBase<Object?>>(BuildContext context) {
    try {
      return context.read<T>();
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedTab = useState<int>(0); // 0: AI Upload, 1: Manual Entry

    // Common Metadata State
    final selectedYear = useState<int>(DateTime.now().year);
    final customYearController = useTextEditingController();
    final isCustomYear = useState<bool>(false);

    // AI Upload State
    final pickedFile = useState<PickedDocument?>(null);
    final isCalibrating = useState<bool>(false);
    final calibrationProgress = useState<double>(0);
    final calibrationStatus = useState<String>('');
    final calibratedQuestions = useState<List<PastQuestionModel>>([]);

    // Manual Entry State
    final isTheoryMode = useState<bool>(false);
    final promptController = useTextEditingController();
    final optionAController = useTextEditingController();
    final optionBController = useTextEditingController();
    final optionCController = useTextEditingController();
    final optionDController = useTextEditingController();
    final correctOptionLabel = useState<String>('A');
    final explanationController = useTextEditingController();
    final topicController = useTextEditingController(text: courseTitle);
    final attachedImagePath = useState<String?>(null);
    final isSubmitting = useState<bool>(false);

    int getEffectiveYear() {
      if (isCustomYear.value) {
        final parsed = int.tryParse(customYearController.text.trim());
        if (parsed != null && parsed >= 1970 && parsed <= 2030) {
          return parsed;
        }
      }
      return selectedYear.value;
    }

    // AI Calibration Handler
    Future<void> handleAiExtraction() async {
      final doc = pickedFile.value;
      if (doc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a past paper document or image.')),
        );
        return;
      }

      isCalibrating.value = true;
      calibrationProgress.value = 0.1;
      calibrationStatus.value = 'Preparing document buffer...';
      AppFeedback.medium();

      try {
        final extractor = locator.isRegistered<PastQuestionAiExtractorService>()
            ? locator<PastQuestionAiExtractorService>()
            : PastQuestionAiExtractorService();

        final result = await extractor.extractAndCalibrateQuestions(
          bytes: doc.bytes,
          extension: doc.extension,
          filename: doc.name,
          courseCode: courseCode,
          courseTitle: courseTitle,
          mappedSubject: mappedSubject,
          examCategory: examCategory,
          year: getEffectiveYear(),
          courseId: courseId,
          onProgress: (p, s) {
            calibrationProgress.value = p;
            calibrationStatus.value = s;
          },
        );

        calibratedQuestions.value = result.questions;
        AppFeedback.heavy();

        if (result.questions.isEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No questions could be isolated from this file. You can enter them manually.'),
            ),
          );
        }
      } on Object catch (e) {
        debugPrint('[AddPastQuestion] Extraction error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calibration notice: $e')),
          );
        }
      } finally {
        isCalibrating.value = false;
      }
    }

    // Save All AI-Calibrated Questions
    Future<void> saveCalibratedQuestions() async {
      final questions = calibratedQuestions.value;
      if (questions.isEmpty) return;

      isSubmitting.value = true;
      AppFeedback.medium();

      try {
        final entities = questions.map((m) => m.toEntity()).toList();

        final bloc = pastQuestionsBloc ??
            (locator.isRegistered<PastQuestionsBloc>()
                ? locator<PastQuestionsBloc>()
                : null);

        if (bloc != null) {
          bloc.add(AddPastQuestionsEvent(entities));
        }
        onAdded?.call(entities);

        AppFeedback.heavy();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${entities.length} past questions to $courseCode!'),
              backgroundColor: colors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    // Save Manual Question
    Future<void> saveManualQuestion() async {
      final prompt = promptController.text.trim();
      if (prompt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the question prompt.')),
        );
        return;
      }

      final isTheory = isTheoryMode.value;
      final options = <String>[];
      var correctIdx = 0;
      var correctLabel = 'A';

      if (!isTheory) {
        final optA = optionAController.text.trim();
        final optB = optionBController.text.trim();
        final optC = optionCController.text.trim();
        final optD = optionDController.text.trim();

        if (optA.isEmpty || optB.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please provide at least Option A and Option B.')),
          );
          return;
        }

        final optList = ['A. $optA', 'B. $optB'];
        if (optC.isNotEmpty) optList.add('C. $optC');
        if (optD.isNotEmpty) optList.add('D. $optD');
        options.addAll(optList);

        correctLabel = correctOptionLabel.value;
        correctIdx = ['A', 'B', 'C', 'D'].indexOf(correctLabel).clamp(0, options.length - 1);
      }

      isSubmitting.value = true;
      AppFeedback.medium();

      try {
        final newQuestion = PastQuestionEntity(
          id: 'pq_user_${UuidUtils.generate()}',
          examType: examCategory,
          subject: mappedSubject,
          year: getEffectiveYear(),
          questionNumber: 1,
          prompt: prompt,
          options: options,
          correctOptionIndex: correctIdx,
          correctOptionLabel: isTheory ? '' : correctLabel,
          explanation: explanationController.text.trim().isNotEmpty
              ? explanationController.text.trim()
              : (isTheory
                  ? 'Model answer verified for $courseCode.'
                  : 'Option $correctLabel is verified based on curriculum standards.'),
          topic: topicController.text.trim().isNotEmpty
              ? topicController.text.trim()
              : courseTitle,
          imageUrl: attachedImagePath.value,
          isUserAdded: true,
          courseId: courseId,
          courseCode: courseCode,
        );

        final bloc = pastQuestionsBloc ??
            (locator.isRegistered<PastQuestionsBloc>()
                ? locator<PastQuestionsBloc>()
                : null);

        if (bloc != null) {
          bloc.add(AddPastQuestionsEvent([newQuestion]));
        }
        onAdded?.call([newQuestion]);

        AppFeedback.heavy();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added question to $courseCode!'),
              backgroundColor: colors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Sheet Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: colors.surfaceBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.post_add_rounded, size: 20, color: colors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Course Past Question',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 16.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$courseCode • $courseTitle',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 20),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppLiquidGlassTabBar(
                tabs: const [
                  'AI Document Upload',
                  'Manual Form Entry',
                ],
                selectedIndex: selectedTab.value,
                onTabSelected: (idx) {
                  AppFeedback.light();
                  selectedTab.value = idx;
                },
                height: 40,
              ),
            ),
            const SizedBox(height: 16),

            // Main Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  // Common Examination Year Picker
                  _buildYearSection(
                    context: context,
                    selectedYear: selectedYear,
                    isCustomYear: isCustomYear,
                    customYearController: customYearController,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  if (selectedTab.value == 0) ...[
                    // --- AI Document Upload View ---
                    _buildAiUploadView(
                      context: context,
                      pickedFile: pickedFile,
                      isCalibrating: isCalibrating.value,
                      calibrationProgress: calibrationProgress.value,
                      calibrationStatus: calibrationStatus.value,
                      calibratedQuestions: calibratedQuestions.value,
                      onPickFile: () async {
                        AppFeedback.light();
                        final doc = await FilePickerService().pickStudyDocument(
                          extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'pptx'],
                        );
                        if (doc != null) {
                          pickedFile.value = doc;
                          calibratedQuestions.value = [];
                        }
                      },
                      onExecuteCalibration: handleAiExtraction,
                      onSaveCalibrated: saveCalibratedQuestions,
                      isSubmitting: isSubmitting.value,
                      colors: colors,
                      typography: typography,
                      isDark: isDark,
                    ),
                  ] else ...[
                    // --- Manual Form Entry View ---
                    _buildManualFormView(
                      context: context,
                      isTheoryMode: isTheoryMode,
                      promptController: promptController,
                      optionAController: optionAController,
                      optionBController: optionBController,
                      optionCController: optionCController,
                      optionDController: optionDController,
                      correctOptionLabel: correctOptionLabel,
                      explanationController: explanationController,
                      topicController: topicController,
                      attachedImagePath: attachedImagePath,
                      onSave: saveManualQuestion,
                      isSubmitting: isSubmitting.value,
                      colors: colors,
                      typography: typography,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Year Selector Helper ---
  Widget _buildYearSection({
    required BuildContext context,
    required ValueNotifier<int> selectedYear,
    required ValueNotifier<bool> isCustomYear,
    required TextEditingController customYearController,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    final recentYears = [
      DateTime.now().year,
      DateTime.now().year - 1,
      DateTime.now().year - 2,
      DateTime.now().year - 3,
      DateTime.now().year - 4,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Examination Year',
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...recentYears.map((yr) {
                final isSelected = !isCustomYear.value && selectedYear.value == yr;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShrinkableButton(
                    onTap: () {
                      AppFeedback.selection();
                      isCustomYear.value = false;
                      selectedYear.value = yr;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isDark ? colors.surfaceSecondary : colors.surfaceBorder.withAlpha(50)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.surfaceBorder,
                        ),
                      ),
                      child: Text(
                        '$yr',
                        style: typography.caption.bold.copyWith(
                          color: isSelected ? colors.white : colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              ShrinkableButton(
                onTap: () {
                  AppFeedback.selection();
                  isCustomYear.value = true;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isCustomYear.value
                        ? colors.primary
                        : (isDark ? colors.surfaceSecondary : colors.surfaceBorder.withAlpha(50)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCustomYear.value ? colors.primary : colors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_calendar_rounded,
                        size: 13,
                        color: isCustomYear.value ? colors.white : colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Other',
                        style: typography.caption.bold.copyWith(
                          color: isCustomYear.value ? colors.white : colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCustomYear.value) ...[
          const SizedBox(height: 10),
          AppTextField(
            controller: customYearController,
            hintText: 'Enter past question year (e.g. 2018)',
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  // --- AI Upload & Calibration View ---
  Widget _buildAiUploadView({
    required BuildContext context,
    required ValueNotifier<PickedDocument?> pickedFile,
    required bool isCalibrating,
    required double calibrationProgress,
    required String calibrationStatus,
    required List<PastQuestionModel> calibratedQuestions,
    required VoidCallback onPickFile,
    required VoidCallback onExecuteCalibration,
    required VoidCallback onSaveCalibrated,
    required bool isSubmitting,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    final file = pickedFile.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Dropzone
        ShrinkableButton(
          onTap: isCalibrating ? null : onPickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary.withAlpha(120) : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: file != null ? colors.primary : colors.surfaceBorder,
                width: file != null ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    file != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                    size: 28,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                if (file == null) ...[
                  Text(
                    'Upload Past Paper (PDF, Images, TXT)',
                    style: typography.body.bold.copyWith(color: colors.textPrimary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Extracts MCQs & theory questions, solves answers & explains reasoning.',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(color: colors.textSecondary, fontSize: 11.5),
                  ),
                ] else ...[
                  Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.bold.copyWith(color: colors.textPrimary, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(file.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB • Ready for AI',
                    style: typography.footnote.regular.copyWith(color: colors.success, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Calibration Progress
        if (isCalibrating) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppLogoLoader(size: 16, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        calibrationStatus,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: calibrationProgress,
                  backgroundColor: colors.primary.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (calibratedQuestions.isEmpty)
          AppButton(
            text: isCalibrating ? 'Analyzing & Calibrating...' : 'Extract & Calibrate with AI',
            isLoading: isCalibrating,
            onPressed: isCalibrating || file == null ? null : onExecuteCalibration,
            prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 16),
          )
        else ...[
          // Calibrated questions preview summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.success.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted ${calibratedQuestions.length} Questions (${calibratedQuestions.where((q) => !q.toEntity().isTheory).length} MCQ, ${calibratedQuestions.where((q) => q.toEntity().isTheory).length} Theory)',
                    style: typography.caption.bold.copyWith(color: colors.success, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Calibrated Question Previews
          ...calibratedQuestions.take(5).map((q) {
            final isTheory = q.options.isEmpty;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTheory
                              ? colors.syllabotAccent.withAlpha(30)
                              : colors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isTheory ? 'THEORY / ESSAY' : 'MULTIPLE CHOICE',
                          style: typography.caption.bold.copyWith(
                            color: isTheory ? colors.syllabotAccent : colors.primary,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                      if (!isTheory)
                        Text(
                          'Correct: ${q.correctOptionLabel}',
                          style: typography.caption.bold.copyWith(color: colors.success, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.prompt,
                    style: typography.body.bold.copyWith(color: colors.textPrimary, fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    q.explanation,
                    style: typography.footnote.regular.copyWith(color: colors.textSecondary, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          AppButton(
            text: 'Save ${calibratedQuestions.length} Questions to $courseCode',
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onSaveCalibrated,
            prefixIcon: const Icon(Icons.bookmark_added_rounded, size: 16),
          ),
        ],
      ],
    );
  }

  // --- Manual Form Entry View ---
  Widget _buildManualFormView({
    required BuildContext context,
    required ValueNotifier<bool> isTheoryMode,
    required TextEditingController promptController,
    required TextEditingController optionAController,
    required TextEditingController optionBController,
    required TextEditingController optionCController,
    required TextEditingController optionDController,
    required ValueNotifier<String> correctOptionLabel,
    required TextEditingController explanationController,
    required TextEditingController topicController,
    required ValueNotifier<String?> attachedImagePath,
    required VoidCallback onSave,
    required bool isSubmitting,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    final isTheory = isTheoryMode.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Selector: Multiple Choice vs Theory
        Row(
          children: [
            Expanded(
              child: ShrinkableButton(
                onTap: () {
                  AppFeedback.selection();
                  isTheoryMode.value = false;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !isTheory
                        ? colors.primary.withAlpha(25)
                        : (isDark ? colors.surfaceSecondary : colors.surfaceBorder.withAlpha(50)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !isTheory ? colors.primary : colors.surfaceBorder,
                      width: !isTheory ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Multiple Choice (MCQ)',
                      style: typography.caption.bold.copyWith(
                        color: !isTheory ? colors.primary : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShrinkableButton(
                onTap: () {
                  AppFeedback.selection();
                  isTheoryMode.value = true;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isTheory
                        ? colors.syllabotAccent.withAlpha(25)
                        : (isDark ? colors.surfaceSecondary : colors.surfaceBorder.withAlpha(50)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isTheory ? colors.syllabotAccent : colors.surfaceBorder,
                      width: isTheory ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Theory / Essay',
                      style: typography.caption.bold.copyWith(
                        color: isTheory ? colors.syllabotAccent : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Prompt
        Text(
          'Question Stem / Problem Statement',
          style: typography.caption.bold.copyWith(color: colors.textPrimary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: promptController,
          hintText: isTheory
              ? 'State, explain, or derive the problem statement...'
              : 'What is the correct definition / answer for...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // MCQ Options
        if (!isTheory) ...[
          Text(
            'Options & Correct Answer',
            style: typography.caption.bold.copyWith(color: colors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildOptionField('A', optionAController, correctOptionLabel, colors, typography),
          const SizedBox(height: 8),
          _buildOptionField('B', optionBController, correctOptionLabel, colors, typography),
          const SizedBox(height: 8),
          _buildOptionField('C', optionCController, correctOptionLabel, colors, typography),
          const SizedBox(height: 8),
          _buildOptionField('D', optionDController, correctOptionLabel, colors, typography),
          const SizedBox(height: 14),
        ],

        // Explanation / Model Answer
        Text(
          isTheory ? 'Model Answer, Rubric & Rationale' : 'Explanation (Why that is the answer)',
          style: typography.caption.bold.copyWith(color: colors.textPrimary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: explanationController,
          hintText: isTheory
              ? 'Provide the complete model solution, formulas, and key points...'
              : 'Detailed step-by-step reasoning explaining why this answer is correct...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // Topic
        Text(
          'Specific Topic / Syllabus Unit',
          style: typography.caption.bold.copyWith(color: colors.textPrimary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: topicController,
          hintText: 'e.g. Data Structures, Thermodynamics',
        ),
        const SizedBox(height: 14),

        // Image Attachment (Optional)
        Row(
          children: [
            Expanded(
              child: Text(
                attachedImagePath.value != null
                    ? 'Diagram: ${attachedImagePath.value!.split('/').last}'
                    : 'Optional Diagram Attachment',
                style: typography.caption.medium.copyWith(
                  color: attachedImagePath.value != null ? colors.primary : colors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                AppFeedback.light();
                final doc = await FilePickerService().pickStudyDocument(
                  extensions: const ['png', 'jpg', 'jpeg'],
                );
                if (doc != null && doc.path != null) {
                  attachedImagePath.value = doc.path;
                }
              },
              icon: Icon(Icons.add_photo_alternate_outlined, size: 16, color: colors.primary),
              label: Text(
                attachedImagePath.value != null ? 'Change' : 'Add Diagram',
                style: typography.caption.bold.copyWith(color: colors.primary, fontSize: 12),
              ),
            ),
            if (attachedImagePath.value != null)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: colors.error),
                onPressed: () {
                  attachedImagePath.value = null;
                },
              ),
          ],
        ),
        const SizedBox(height: 20),

        AppButton(
          text: isSubmitting ? 'Saving Question...' : 'Save Question to $courseCode',
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onSave,
          prefixIcon: const Icon(Icons.add_task_rounded, size: 16),
        ),
      ],
    );
  }

  Widget _buildOptionField(
    String letter,
    TextEditingController controller,
    ValueNotifier<String> selectedCorrect,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    final isCorrect = selectedCorrect.value == letter;

    return Row(
      children: [
        ShrinkableButton(
          onTap: () {
            AppFeedback.selection();
            selectedCorrect.value = letter;
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCorrect ? colors.success : colors.surfaceBorder.withAlpha(60),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                letter,
                style: typography.caption.bold.copyWith(
                  color: isCorrect ? colors.white : colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppTextField(
            controller: controller,
            hintText: 'Option $letter',
          ),
        ),
      ],
    );
  }
}
