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
