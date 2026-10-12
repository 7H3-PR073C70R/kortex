import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/services/past_question_ai_extractor_service.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_question/add_question_ai_upload_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_question/add_question_manual_form_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_question/add_question_year_selector.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

export 'package:kortex/src/features/quiz/presentation/widgets/add_question/add_question_ai_upload_view.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/add_question/add_question_manual_form_view.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/add_question/add_question_year_selector.dart';

class AddPastQuestionModalSheet extends HookWidget {
  const AddPastQuestionModalSheet({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.examCategory,
    this.pastQuestionsBloc,
    this.aiExtractorService,
    this.onAdded,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final ExamCategory examCategory;
  final PastQuestionsBloc? pastQuestionsBloc;
  final PastQuestionAiExtractorService? aiExtractorService;
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
    PastQuestionAiExtractorService? aiExtractorService,
    void Function(List<PastQuestionEntity>)? onAdded,
  }) {
    final effectiveSubject =
        mappedSubject ?? defaultSubject ?? 'General Studies';
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

    return AppAdaptiveSheet.showModal<bool>(
      context: context,
      maxWidth: 640,
      builder: (ctx) => AddPastQuestionModalSheet(
        courseId: effectiveCourseId,
        courseCode: effectiveCourseCode,
        courseTitle: effectiveCourseTitle,
        mappedSubject: effectiveSubject,
        examCategory: effectiveExamCategory,
        pastQuestionsBloc: bloc,
        aiExtractorService: aiExtractorService,
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
    final calibratedQuestions = useState<List<PastQuestionEntity>>([]);

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
        context.showSnackBar(
          message: 'Please select a past paper document or image.',
        );
        return;
      }

      isCalibrating.value = true;
      calibrationProgress.value = 0.1;
      calibrationStatus.value = 'Preparing document buffer...';
      AppFeedback.medium();

      try {
        final extractor = aiExtractorService ??
            (locator.isRegistered<PastQuestionAiExtractorService>()
                ? locator<PastQuestionAiExtractorService>()
                : PastQuestionAiExtractorService());

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

        calibratedQuestions.value =
            result.questions.map((m) => m.toEntity()).toList();
        AppFeedback.heavy();

        if (result.questions.isEmpty && context.mounted) {
          context.showSnackBar(
            message:
                'No questions could be isolated from this file. You can enter them manually.',
          );
        }
      } on Object catch (e) {
        debugPrint('[AddPastQuestion] Extraction error: $e');
        if (context.mounted) {
          context.showSnackBar(
            message:
                'We could not read this file. Try again, or enter the questions manually.',
            type: SnackBarType.error,
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
        final bloc = pastQuestionsBloc ??
            (locator.isRegistered<PastQuestionsBloc>()
                ? locator<PastQuestionsBloc>()
                : null);

        if (bloc != null) {
          bloc.add(AddPastQuestionsEvent(questions));
        }
        onAdded?.call(questions);

        AppFeedback.heavy();
        if (context.mounted) {
          context.showSnackBar(
            message: 'Added ${questions.length} past questions to $courseCode!',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop(true);
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    // Save Manual Question
    Future<void> saveManualQuestion(PastQuestionEntity newQuestion) async {
      isSubmitting.value = true;
      AppFeedback.medium();

      try {
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
          context.showSnackBar(
            message: 'Added question to $courseCode!',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop(true);
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Align(
      alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
            border: isDesktop
                ? Border.all(color: colors.surfaceBorder)
                : null,
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 100 : 35),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            top: isDesktop,
            child: Column(
              children: [
                // Sheet Drag Handle & Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      if (!isDesktop) ...[
                        Center(
                          child: Container(
                            width: 42,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: colors.surfaceBorder,
                              borderRadius: BorderRadius.circular(
                                AppRadius.micro,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Icon(
                              Icons.post_add_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
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
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.textSecondary,
                              size: 20,
                            ),
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
                      AddQuestionYearSelector(
                        selectedYear: selectedYear,
                        isCustomYear: isCustomYear,
                        customYearController: customYearController,
                      ),
                      const SizedBox(height: 20),

                      if (selectedTab.value == 0) ...[
                        // --- AI Document Upload View ---
                        AddQuestionAiUploadView(
                          pickedFile: pickedFile,
                          isCalibrating: isCalibrating.value,
                          calibrationProgress: calibrationProgress.value,
                          calibrationStatus: calibrationStatus.value,
                          calibratedQuestions: calibratedQuestions.value,
                          onPickFile: () async {
                            AppFeedback.light();
                            final doc = await FilePickerService()
                                .pickStudyDocument(
                              extensions: const [
                                'pdf',
                                'png',
                                'jpg',
                                'jpeg',
                                'txt',
                                'pptx',
                              ],
                            );
                            if (doc != null) {
                              pickedFile.value = doc;
                              calibratedQuestions.value = [];
                            }
                          },
                          onExecuteCalibration: handleAiExtraction,
                          onSaveCalibrated: saveCalibratedQuestions,
                          isSubmitting: isSubmitting.value,
                          courseCode: courseCode,
                        ),
                      ] else ...[
                        // --- Manual Form Entry View ---
                        AddQuestionManualFormView(
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
                          onSaveQuestion: (q) =>
                              unawaited(saveManualQuestion(q)),
                          isSubmitting: isSubmitting.value,
                          courseCode: courseCode,
                          courseTitle: courseTitle,
                          courseId: courseId,
                          mappedSubject: mappedSubject,
                          examCategory: examCategory,
                          effectiveYear: getEffectiveYear(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
