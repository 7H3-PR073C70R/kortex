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

/// Thrown when no usable text could be extracted from a document, so no
/// trustworthy cards can be produced offline.
class NoReadableTextException implements Exception {
  const NoReadableTextException({this.message});

  final String? message;

  @override
  String toString() => message ?? defaultMessage;

  static const defaultMessage =
      "Couldn't read this document offline. "
      'Try again when you are online.';
}

/// Thrown when user reaches the maximum active device slot quota (3 devices).
class DeviceLimitExceededException implements Exception {
  const DeviceLimitExceededException({
    required this.message,
    this.activeDevices = const [],
  });

  final String message;
  final List<Map<String, dynamic>> activeDevices;

  @override
  String toString() => message;
}
