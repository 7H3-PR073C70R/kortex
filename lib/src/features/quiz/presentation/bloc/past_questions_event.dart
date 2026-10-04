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
    this.courseId,
    this.courseCode,
    this.isScopedToUserTrack,
    this.userTrack,
    this.enrolledCourseCodes,
    this.enrolledCourseIds,
  });

  final ExamCategory? examCategory;
  final String? subject;
  final int? year;
  final String? searchQuery;
  final String? courseId;
  final String? courseCode;
  final bool? isScopedToUserTrack;
  final String? userTrack;
  final List<String>? enrolledCourseCodes;
  final List<String>? enrolledCourseIds;

  @override
  List<Object?> get props => [
    examCategory,
    subject,
    year,
    searchQuery,
    courseId,
    courseCode,
    isScopedToUserTrack,
    userTrack,
    enrolledCourseCodes,
    enrolledCourseIds,
  ];
}

class SetTrackScopeEvent extends PastQuestionsEvent {
  const SetTrackScopeEvent({
    required this.isScopedToUserTrack,
    this.userTrack,
    this.enrolledCourseCodes,
    this.enrolledCourseIds,
  });

  final bool isScopedToUserTrack;
  final String? userTrack;
  final List<String>? enrolledCourseCodes;
  final List<String>? enrolledCourseIds;

  @override
  List<Object?> get props => [
    isScopedToUserTrack,
    userTrack,
    enrolledCourseCodes,
    enrolledCourseIds,
  ];
}

class AddPastQuestionsEvent extends PastQuestionsEvent {
  const AddPastQuestionsEvent(this.questions);
  final List<PastQuestionEntity> questions;

  @override
  List<Object?> get props => [questions];
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
