import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

enum PastQuestionsStatus { initial, loading, loaded, failure }

class PastQuestionsState extends Equatable {
  const PastQuestionsState({
    this.status = PastQuestionsStatus.initial,
    this.questions = const [],
    this.selectedExam = ExamCategory.waec,
    this.selectedSubject = 'All',
    this.selectedYear,
    this.availableSubjects = const [],
    this.availableYears = const [],
    this.isInstantFeedbackMode = true,
    this.searchQuery = '',
    this.errorMessage,
  });

  final PastQuestionsStatus status;
  final List<PastQuestionEntity> questions;
  final ExamCategory selectedExam;
  final String selectedSubject;
  final int? selectedYear;
  final List<String> availableSubjects;
  final List<int> availableYears;
  final bool isInstantFeedbackMode;
  final String searchQuery;
  final String? errorMessage;

  int get totalQuestions => questions.length;
  int get answeredQuestions => questions.where((q) => q.isAnswered).length;
  int get correctAnswers => questions.where((q) => q.isCorrect).length;

  PastQuestionsState copyWith({
    PastQuestionsStatus? status,
    List<PastQuestionEntity>? questions,
    ExamCategory? selectedExam,
    String? selectedSubject,
    int? selectedYear,
    bool clearSelectedYear = false,
    List<String>? availableSubjects,
    List<int>? availableYears,
    bool? isInstantFeedbackMode,
    String? searchQuery,
    String? errorMessage,
  }) {
    return PastQuestionsState(
      status: status ?? this.status,
      questions: questions ?? this.questions,
      selectedExam: selectedExam ?? this.selectedExam,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedYear: clearSelectedYear
          ? null
          : (selectedYear ?? this.selectedYear),
      availableSubjects: availableSubjects ?? this.availableSubjects,
      availableYears: availableYears ?? this.availableYears,
      isInstantFeedbackMode:
          isInstantFeedbackMode ?? this.isInstantFeedbackMode,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    questions,
    selectedExam,
    selectedSubject,
    selectedYear,
    availableSubjects,
    availableYears,
    isInstantFeedbackMode,
    searchQuery,
    errorMessage,
  ];
}
