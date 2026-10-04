import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';

class PastQuestionsBloc extends Bloc<PastQuestionsEvent, PastQuestionsState> {
  PastQuestionsBloc({
    required PastQuestionsRepository repository,
    UserActivityService? userActivityService,
  }) : _repository = repository,
       _userActivityService = userActivityService,
       super(const PastQuestionsState()) {
    on<LoadPastQuestionsEvent>(_onLoadPastQuestions);
    on<SetTrackScopeEvent>(_onSetTrackScope);
    on<AddPastQuestionsEvent>(_onAddPastQuestions);
    on<ChangeExamCategoryEvent>(_onChangeExamCategory);
    on<ChangeSubjectEvent>(_onChangeSubject);
    on<ChangeYearEvent>(_onChangeYear);
    on<SelectOptionEvent>(_onSelectOption);
    on<ToggleBookmarkEvent>(_onToggleBookmark);
    on<TogglePracticeModeEvent>(_onTogglePracticeMode);
  }

  final PastQuestionsRepository _repository;
  final UserActivityService? _userActivityService;

  Future<void> _onSetTrackScope(
    SetTrackScopeEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    emit(
      state.copyWith(
        isScopedToUserTrack: event.isScopedToUserTrack,
        userTrack: event.userTrack ?? state.userTrack,
        enrolledCourseCodes:
            event.enrolledCourseCodes ?? state.enrolledCourseCodes,
        enrolledCourseIds: event.enrolledCourseIds ?? state.enrolledCourseIds,
      ),
    );
    add(
      LoadPastQuestionsEvent(
        isScopedToUserTrack: event.isScopedToUserTrack,
        userTrack: event.userTrack ?? state.userTrack,
        enrolledCourseCodes:
            event.enrolledCourseCodes ?? state.enrolledCourseCodes,
        enrolledCourseIds: event.enrolledCourseIds ?? state.enrolledCourseIds,
      ),
    );
  }

  Future<void> _onLoadPastQuestions(
    LoadPastQuestionsEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    final isScoped = event.isScopedToUserTrack ?? state.isScopedToUserTrack;
    final userTrack = event.userTrack ?? state.userTrack;
    final enrolledCodes =
        event.enrolledCourseCodes ?? state.enrolledCourseCodes;
    final enrolledIds = event.enrolledCourseIds ?? state.enrolledCourseIds;

    emit(
      state.copyWith(
        status: PastQuestionsStatus.loading,
        isScopedToUserTrack: isScoped,
        userTrack: userTrack,
        enrolledCourseCodes: enrolledCodes,
        enrolledCourseIds: enrolledIds,
      ),
    );

    final exam = event.examCategory ?? state.selectedExam;
    final subject = event.subject ?? state.selectedSubject;
    final year = event.year ?? state.selectedYear;
    final courseId = event.courseId ?? state.courseId;
    final courseCode = event.courseCode ?? state.courseCode;

    final subjectsRes = await _repository.getAvailableSubjects(exam);
    final yearsRes = await _repository.getAvailableYears(exam);

    final questionsRes = await _repository.getPastQuestions(
      examCategory: exam,
      subject: subject == 'All' ? null : subject,
      year: year,
      searchQuery: event.searchQuery ?? state.searchQuery,
      courseId: courseId,
      courseCode: courseCode,
    );

    questionsRes.fold(
      (failure) => emit(
        state.copyWith(
          status: PastQuestionsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (questions) {
        final availSubjects = subjectsRes.fold<List<String>>(
          (_) => [],
          List<String>.from,
        );
        if (subject != 'All' && !availSubjects.contains(subject)) {
          availSubjects.insert(0, subject);
        }

        // Filter questions if track scope is strictly enabled
        var filteredQuestions = questions;
        if (isScoped && enrolledCodes.isNotEmpty) {
          final cleanCodes = enrolledCodes.map((c) => c.toLowerCase()).toSet();
          filteredQuestions = questions.where((q) {
            if (q.courseCode != null &&
                cleanCodes.contains(q.courseCode!.toLowerCase())) {
              return true;
            }
            if (enrolledIds.contains(q.courseId)) return true;
            // Also match if question subject is in enrolled course codes or title list
            final subjLower = q.subject.toLowerCase();
            return cleanCodes.any(subjLower.contains);
          }).toList();

          // Fallback to original list if course-specific filtering yields empty set
          if (filteredQuestions.isEmpty && questions.isNotEmpty) {
            filteredQuestions = questions;
          }
        }

        emit(
          state.copyWith(
            status: PastQuestionsStatus.loaded,
            questions: filteredQuestions,
            selectedExam: exam,
            selectedSubject: subject,
            selectedYear: year,
            courseId: courseId,
            courseCode: courseCode,
            availableSubjects: availSubjects,
            availableYears: yearsRes.fold((_) => [], List<int>.from),
          ),
        );
      },
    );
  }

  Future<void> _onAddPastQuestions(
    AddPastQuestionsEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    if (event.questions.isEmpty) return;
    await _repository.savePastQuestions(event.questions);

    final existingIds = state.questions.map((q) => q.id).toSet();
    final newQuestions = <PastQuestionEntity>[];
    for (final q in event.questions) {
      if (!existingIds.contains(q.id)) {
        newQuestions.add(q);
        existingIds.add(q.id);
      }
    }

    final updatedQuestions = [...newQuestions, ...state.questions];
    emit(
      state.copyWith(
        status: PastQuestionsStatus.loaded,
        questions: updatedQuestions,
      ),
    );
  }

  Future<void> _onChangeExamCategory(
    ChangeExamCategoryEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedExam: event.category,
        selectedSubject: 'All',
        clearSelectedYear: true,
      ),
    );
    add(LoadPastQuestionsEvent(examCategory: event.category));
  }

  Future<void> _onChangeSubject(
    ChangeSubjectEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    emit(state.copyWith(selectedSubject: event.subject));
    add(
      LoadPastQuestionsEvent(
        examCategory: state.selectedExam,
        subject: event.subject,
        year: state.selectedYear,
      ),
    );
  }

  Future<void> _onChangeYear(
    ChangeYearEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    emit(
      event.year == null
          ? state.copyWith(clearSelectedYear: true)
          : state.copyWith(selectedYear: event.year),
    );
    add(
      LoadPastQuestionsEvent(
        examCategory: state.selectedExam,
        subject: state.selectedSubject,
        year: event.year,
      ),
    );
  }

  Future<void> _onSelectOption(
    SelectOptionEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    final targetIndex =
        state.questions.indexWhere((q) => q.id == event.questionId);
    final prevQuestion =
        targetIndex != -1 ? state.questions[targetIndex] : null;
    final wasAlreadyAnswered = prevQuestion?.isAnswered ?? false;

    final updated = state.questions.map((q) {
      if (q.id == event.questionId) {
        return q.copyWith(userSelectedOptionIndex: event.optionIndex);
      }
      return q;
    }).toList();

    emit(state.copyWith(questions: updated));

    // If answering this past question for the first time, record study progress
    // so that streaks increase and streak protection applies without flashcards.
    if (prevQuestion != null && !wasAlreadyAnswered) {
      try {
        final activity = _userActivityService ??
            (locator.isRegistered<UserActivityService>()
                ? locator<UserActivityService>()
                : null);
        if (activity != null) {
          final isCorrect =
              event.optionIndex == prevQuestion.correctOptionIndex;
          await activity.recordStudySession(
            cardsReviewed: 1,
            durationSeconds: 30,
            retentionScore: isCorrect ? 1.0 : 0.0,
            masteredCards: isCorrect ? 1 : 0,
            activityCategory: 'past_questions',
            subject: prevQuestion.subject,
          );
        }
      } on Object catch (_) {}
    }
  }

  Future<void> _onToggleBookmark(
    ToggleBookmarkEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    await _repository.toggleBookmarkQuestion(event.questionId);
    final updated = state.questions.map((q) {
      if (q.id == event.questionId) {
        return q.copyWith(isBookmarked: !q.isBookmarked);
      }
      return q;
    }).toList();

    emit(state.copyWith(questions: updated));
  }

  void _onTogglePracticeMode(
    TogglePracticeModeEvent event,
    Emitter<PastQuestionsState> emit,
  ) {
    emit(
      state.copyWith(
        isInstantFeedbackMode: !state.isInstantFeedbackMode,
      ),
    );
  }
}
