import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';

/// State coordinator for academic assessment creation and editing.
///
/// Decouples form validation, course catalog loading, workload calculations,
/// and timetable synchronization from UI presentation widgets.
class AssessmentFormCoordinator extends ChangeNotifier {
  AssessmentFormCoordinator({
    this.initialExam,
    this.preselectedCourseCode,
    this.preselectedCourseTitle,
    this.preselectedType,
    LocalStorageService? localStorageService,
    DecksBloc? decksBloc,
    AuthBloc? authBloc,
    CramPlannerCubit? cramPlannerCubit,
    PastQuestionsRepository? pastQuestionsRepository,
  })  : _localStorageService = localStorageService,
        _decksBloc = decksBloc,
        _authBloc = authBloc,
        _cramPlannerCubit = cramPlannerCubit,
        _pastQuestionsRepository = pastQuestionsRepository {
    _init();
  }

  final ExamEventEntity? initialExam;
  final String? preselectedCourseCode;
  final String? preselectedCourseTitle;
  final AssessmentType? preselectedType;

  final LocalStorageService? _localStorageService;
  final DecksBloc? _decksBloc;
  final AuthBloc? _authBloc;
  final CramPlannerCubit? _cramPlannerCubit;
  final PastQuestionsRepository? _pastQuestionsRepository;

  late final TextEditingController nameController;
  late final TextEditingController topicController;

  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  late AssessmentType selectedType;
  final Set<String> selectedDeckIds = {};
  final List<String> scopedTopics = [];
  double? selectedWeightPercent;

  List<CuratedCourseModel> registeredCourses = [];
  CuratedCourseModel? selectedCourse;
  List<DeckEntity> courseDecks = [];
  int deckCardsCount = 0;
  int pastQuestionsCount = 0;
  bool isCalculatingWorkload = false;
  bool userCustomizedTitle = false;

  void _init() {
    selectedType = initialExam?.assessmentType ??
        preselectedType ??
        AssessmentType.finalExam;

    nameController = TextEditingController(
      text: initialExam?.examName ?? '',
    );
    topicController = TextEditingController();

    if (initialExam != null && initialExam!.examName.isNotEmpty) {
      userCustomizedTitle = true;
    }

    selectedDate = initialExam?.targetDate ??
        DateTime.now().add(Duration(days: selectedType.suggestedDaysAhead));

    selectedTime = initialExam != null
        ? TimeOfDay(
            hour: initialExam!.targetDate.hour,
            minute: initialExam!.targetDate.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);

    if (initialExam != null && initialExam!.scopedDeckIds.isNotEmpty) {
      selectedDeckIds.addAll(initialExam!.scopedDeckIds);
    }
    if (initialExam != null && initialExam!.scopedTopics.isNotEmpty) {
      scopedTopics.addAll(initialExam!.scopedTopics);
    }

    selectedWeightPercent = initialExam?.weightPercent;

    loadRegisteredCourses();
  }

  @override
  void dispose() {
    nameController.dispose();
    topicController.dispose();
    super.dispose();
  }

  void onNameChanged(String val) {
    if (val.trim().isNotEmpty) {
      userCustomizedTitle = true;
    }
    notifyListeners();
  }

  void onWeightSelected(double? weight) {
    selectedWeightPercent = weight;
    notifyListeners();
  }

  void onCourseSelected(CuratedCourseModel course) {
    selectedCourse = course;
    userCustomizedTitle = false;
    syncDefaultTitleAndDecks();
    unawaited(calculateWorkload());
    notifyListeners();
  }

  void addTopic() {
    final text = topicController.text.trim();
    final sanitizedText = sanitizeString(text);
    if (sanitizedText.isNotEmpty && !scopedTopics.contains(sanitizedText)) {
      AppFeedback.selection();
      scopedTopics.add(sanitizedText);
      topicController.clear();
      notifyListeners();
    }
  }

  void removeTopic(String topic) {
    AppFeedback.selection();
    scopedTopics.remove(topic);
    notifyListeners();
  }

  String sanitizeString(String val) {
    return val
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
  }

  void loadRegisteredCourses() {
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      final raw = storage?.getPreference(key: PrefKeys.userCuratedCourses);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        registeredCourses = list
            .whereType<Map<String, dynamic>>()
            .map(CuratedCourseModel.fromJson)
            .toList();
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }

    if (registeredCourses.isNotEmpty) {
      final targetCode = preselectedCourseCode ?? initialExam?.subjectTrack;
      if (targetCode != null && targetCode.isNotEmpty) {
        selectedCourse = registeredCourses.firstWhere(
          (c) {
            final t = targetCode.toLowerCase();
            final code = c.courseCode.toLowerCase();
            final title = c.title.toLowerCase();
            return code == t ||
                title == t ||
                t.contains(code) ||
                t.contains(title);
          },
          orElse: () => registeredCourses.first,
        );
      } else {
        selectedCourse = registeredCourses.first;
      }
    }

    syncDefaultTitleAndDecks();
    unawaited(calculateWorkload());
    notifyListeners();
  }

  void syncDefaultTitleAndDecks() {
    if (selectedCourse == null) return;

    final decksBloc = _decksBloc ??
        (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null);
    if (decksBloc != null) {
      final all = decksBloc.state.allDecks;
      final courseCode = selectedCourse!.courseCode.toLowerCase();
      final courseTitle = selectedCourse!.title.toLowerCase();
      courseDecks = all.where((d) {
        final matchId =
            d.courseId != null && d.courseId == selectedCourse!.id;
        final matchCode = d.courseCode != null &&
            d.courseCode!.toLowerCase() == courseCode;
        final matchSubj = d.subject.toLowerCase() == courseTitle ||
            d.subject.toLowerCase() == courseCode;
        return matchId || matchCode || matchSubj;
      }).toList();

      if (selectedDeckIds.isEmpty && courseDecks.isNotEmpty) {
        selectedDeckIds.addAll(courseDecks.map((d) => d.id));
      }
    }

    if (!userCustomizedTitle || nameController.text.trim().isEmpty) {
      nameController.text =
          selectedType.defaultNameForCourse(selectedCourse!.courseCode);
    }
  }

  void onTypeChanged(AssessmentType type) {
    if (selectedType == type) return;
    AppFeedback.selection();
    selectedType = type;
    if (!userCustomizedTitle && selectedCourse != null) {
      nameController.text =
          type.defaultNameForCourse(selectedCourse!.courseCode);
    }
    if (initialExam == null) {
      selectedDate =
          DateTime.now().add(Duration(days: type.suggestedDaysAhead));
    }
    unawaited(calculateWorkload());
    notifyListeners();
  }

  void toggleDeckSelection(String deckId) {
    AppFeedback.selection();
    if (selectedDeckIds.contains(deckId)) {
      selectedDeckIds.remove(deckId);
    } else {
      selectedDeckIds.add(deckId);
    }
    unawaited(calculateWorkload());
    notifyListeners();
  }

  void selectAllDecks() {
    AppFeedback.selection();
    selectedDeckIds.addAll(courseDecks.map((d) => d.id));
    unawaited(calculateWorkload());
    notifyListeners();
  }

  void clearAllDecks() {
    AppFeedback.selection();
    selectedDeckIds.clear();
    unawaited(calculateWorkload());
    notifyListeners();
  }

  Future<void> calculateWorkload() async {
    isCalculatingWorkload = true;
    notifyListeners();

    var deckCards = 0;
    var pastQuestions = 0;

    final course = selectedCourse;
    if (course != null) {
      for (final d in courseDecks) {
        if (selectedDeckIds.isEmpty || selectedDeckIds.contains(d.id)) {
          deckCards += d.totalCards;
        }
      }

      final isHighStakes = selectedType == AssessmentType.finalExam ||
          selectedType == AssessmentType.mockExam ||
          selectedType == AssessmentType.midterm;

      if (isHighStakes) {
        try {
          final authBloc = _authBloc ??
              (locator.isRegistered<AuthBloc>() ? locator<AuthBloc>() : null);
          final track = (authBloc?.state.userProfile?.targetTrack ?? 'WAEC')
              .toUpperCase();
          final isSecondary = track.contains('WAEC') ||
              track.contains('JAMB') ||
              track.contains('NECO');

          if (isSecondary) {
            final repo = _pastQuestionsRepository ??
                (locator.isRegistered<PastQuestionsRepository>()
                    ? locator<PastQuestionsRepository>()
                    : null);
            if (repo != null) {
              final examCategory = track.contains('JAMB')
                  ? ExamCategory.jamb
                  : (track.contains('NECO')
                      ? ExamCategory.neco
                      : ExamCategory.waec);

              final res = await repo.getPastQuestions(
                examCategory: examCategory,
                subject: course.title,
                courseCode: course.courseCode,
              );
              res.fold(
                (failure) => null,
                (questions) {
                  final limit =
                      selectedType == AssessmentType.midterm ? 250 : 1000;
                  pastQuestions = questions.length > limit
                      ? limit
                      : questions.length;
                },
              );
            }
          }
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }
      }
    }

    deckCardsCount = deckCards;
    pastQuestionsCount = pastQuestions;
    isCalculatingWorkload = false;
    notifyListeners();
  }

  int get totalWorkload => deckCardsCount + pastQuestionsCount;

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final diff = target.difference(today).inDays;
    return diff < 1 ? 1 : diff;
  }

  int get dailyTarget => (totalWorkload / daysRemaining).ceil();

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(now) ? now : selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      selectedDate = picked;
      unawaited(calculateWorkload());
      notifyListeners();
    }
  }

  Future<void> pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      selectedTime = picked;
      notifyListeners();
    }
  }

  Future<void> submit({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final sanitizedName = sanitizeString(nameController.text);
    if (sanitizedName.isEmpty) {
      context.showSnackBar(
        message: 'Please enter a valid assessment title.',
        type: SnackBarType.error,
      );
      return;
    }

    final targetDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final cubit = _cramPlannerCubit ??
        (locator.isRegistered<CramPlannerCubit>()
            ? locator<CramPlannerCubit>()
            : null);

    if (cubit == null) return;

    final courseIdentifier = selectedCourse != null
        ? '${selectedCourse!.courseCode} - ${selectedCourse!.title}'
        : (initialExam?.subjectTrack ?? 'Academic Course');

    final workload = totalWorkload > 0 ? totalWorkload : 50;

    try {
      if (initialExam != null) {
        await cubit.updateExamCountdown(
          examId: initialExam!.id,
          examName: sanitizedName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          assessmentType: selectedType,
          scopedDeckIds: selectedDeckIds.toList(),
          scopedTopics: scopedTopics,
          weightPercent: selectedWeightPercent,
          totalCardsCount: workload,
        );
      } else {
        await cubit.addExamCountdown(
          examName: sanitizedName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          assessmentType: selectedType,
          scopedDeckIds: selectedDeckIds.toList(),
          scopedTopics: scopedTopics,
          weightPercent: selectedWeightPercent,
          totalCardsCount: workload,
        );
      }

      AppFeedback.heavy();
      if (context.mounted) {
        context.showSnackBar(
          message: initialExam != null
              ? 'Assessment countdown updated successfully!'
              : 'Academic assessment added to your timetable!',
          type: SnackBarType.success,
        );
        context.router.pop();
      }
    } on Object catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          message: 'Could not save assessment: $e',
          type: SnackBarType.error,
        );
      }
    }
  }
}
