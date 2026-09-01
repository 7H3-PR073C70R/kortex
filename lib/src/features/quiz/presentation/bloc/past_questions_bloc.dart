import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';

class PastQuestionsBloc extends Bloc<PastQuestionsEvent, PastQuestionsState> {
  PastQuestionsBloc({
    required PastQuestionsRepository repository,
  })  : _repository = repository,
        super(const PastQuestionsState()) {
    on<LoadPastQuestionsEvent>(_onLoadPastQuestions);
    on<ChangeExamCategoryEvent>(_onChangeExamCategory);
    on<ChangeSubjectEvent>(_onChangeSubject);
    on<ChangeYearEvent>(_onChangeYear);
    on<SelectOptionEvent>(_onSelectOption);
    on<ToggleBookmarkEvent>(_onToggleBookmark);
    on<TogglePracticeModeEvent>(_onTogglePracticeMode);
  }

  final PastQuestionsRepository _repository;

  Future<void> _onLoadPastQuestions(
    LoadPastQuestionsEvent event,
    Emitter<PastQuestionsState> emit,
  ) async {
    emit(state.copyWith(status: PastQuestionsStatus.loading));

    final exam = event.examCategory ?? state.selectedExam;
    final subject = event.subject ?? state.selectedSubject;
    final year = event.year ?? state.selectedYear;

    final subjectsRes = await _repository.getAvailableSubjects(exam);
    final yearsRes = await _repository.getAvailableYears(exam);

    final questionsRes = await _repository.getPastQuestions(
      examCategory: exam,
      subject: subject == 'All' ? null : subject,
      year: year,
      searchQuery: event.searchQuery ?? state.searchQuery,
    );

    questionsRes.fold(
      (failure) => emit(
        state.copyWith(
          status: PastQuestionsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (questions) {
        emit(
          state.copyWith(
            status: PastQuestionsStatus.loaded,
            questions: questions,
            selectedExam: exam,
            selectedSubject: subject,
            selectedYear: year,
            availableSubjects: subjectsRes.fold((_) => [], (list) => list),
            availableYears: yearsRes.fold((_) => [], (list) => list),
          ),
        );
      },
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

  void _onSelectOption(
    SelectOptionEvent event,
    Emitter<PastQuestionsState> emit,
  ) {
    final updated = state.questions.map((q) {
      if (q.id == event.questionId) {
        return q.copyWith(userSelectedOptionIndex: event.optionIndex);
      }
      return q;
    }).toList();

    emit(state.copyWith(questions: updated));
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
