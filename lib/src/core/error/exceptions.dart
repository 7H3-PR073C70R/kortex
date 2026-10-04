class ServerException implements Exception {
  const ServerException({this.trace, this.message});

  final StackTrace? trace;
  final String? message;
}

class QuizQuestionsUnavailableException implements Exception {
  const QuizQuestionsUnavailableException({
    required this.subject,
    this.message,
  });

  final String subject;
  final String? message;

  @override
  String toString() => message ?? 'No quiz questions available for $subject.';
}
