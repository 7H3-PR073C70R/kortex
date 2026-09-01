import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

abstract class PastQuestionsEvent extends Equatable {
  const PastQuestionsEvent();

  @override
  List<Object?> get props => [];
}

class LoadPastQuestionsEvent extends PastQuestionsEvent {
  const LoadPastQuestionsEvent({
    this.examCategory,
    this.subject,
    this.year,
    this.searchQuery,
  });

  final ExamCategory? examCategory;
  final String? subject;
  final int? year;
  final String? searchQuery;

  @override
  List<Object?> get props => [examCategory, subject, year, searchQuery];
}

class ChangeExamCategoryEvent extends PastQuestionsEvent {
  const ChangeExamCategoryEvent(this.category);
  final ExamCategory category;

  @override
  List<Object?> get props => [category];
}

class ChangeSubjectEvent extends PastQuestionsEvent {
  const ChangeSubjectEvent(this.subject);
  final String subject;

  @override
  List<Object?> get props => [subject];
}

class ChangeYearEvent extends PastQuestionsEvent {
  const ChangeYearEvent(this.year);
  final int? year;

  @override
  List<Object?> get props => [year];
}

class SelectOptionEvent extends PastQuestionsEvent {
  const SelectOptionEvent({
    required this.questionId,
    required this.optionIndex,
  });

  final String questionId;
  final int optionIndex;

  @override
  List<Object?> get props => [questionId, optionIndex];
}

class ToggleBookmarkEvent extends PastQuestionsEvent {
  const ToggleBookmarkEvent(this.questionId);
  final String questionId;

  @override
  List<Object?> get props => [questionId];
}

class TogglePracticeModeEvent extends PastQuestionsEvent {
  const TogglePracticeModeEvent();
}
