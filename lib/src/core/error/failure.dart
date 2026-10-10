import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message, this.statusCode);

  final String? message;
  final int? statusCode;

  @override
  List<Object> get props => [];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure({
    String? message,
    int? statusCode,
  }) : super(message, statusCode);
}

class CacheFailure extends Failure {
  const CacheFailure({
    String? message,
    int? statusCode,
  }) : super(message, statusCode);
}

class AuthFailure extends Failure {
  const AuthFailure({
    String? message,
    int? statusCode,
  }) : super(message, statusCode);
}

class NoQuizQuestionsFailure extends Failure {
  const NoQuizQuestionsFailure({
    required this.subject,
    String? message,
    int? statusCode,
  }) : super(
          message ??
              'No questions found for $subject. Connect to the internet to generate questions, or create flashcards for this course to play offline.',
          statusCode,
        );

  final String subject;

  @override
  List<Object> get props => [subject, ?message];
}

class NoReadableTextFailure extends Failure {
  const NoReadableTextFailure({
    String? message,
    int? statusCode,
  }) : super(
         message ??
             "Couldn't read this document offline. "
                 'Try again when you are online.',
         statusCode,
       );
}
