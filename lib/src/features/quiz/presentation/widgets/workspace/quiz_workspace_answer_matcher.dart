import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';

/// True when the session behaves like a real paper: no marks until the end.
bool isExamSession(QuizSessionState state) =>
    state.assessmentMode == AssessmentMode.examSimulationMode;

/// Answer comparison that ignores decoration and case.
bool isSameAnswer(String option, String correctAnswer) {
  final cleanCorrect = QuizContentSanitizer.cleanOptionText(
    correctAnswer,
  ).toLowerCase();
  final cleanOption = QuizContentSanitizer.cleanOptionText(
    option,
  ).toLowerCase();
  if (cleanCorrect.isEmpty) return false;
  return cleanCorrect == cleanOption ||
      option.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
}

/// The nudge offered before an answer, and repeated after a miss.
String quizQuestionHintText(QuizQuestionEntity question) {
  final topic = question.subTopic.trim().isNotEmpty
      ? question.subTopic.trim()
      : 'the core idea';
  return 'Start with $topic, then rule out the options that sound absolute.';
}
