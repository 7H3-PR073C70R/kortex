import 'package:dio/dio.dart';
import 'package:kortex/src/core/utils/error_message_handler.dart';

extension DioExceptionExtension on DioException {
  String get errorMessage {
    return (this as Exception).errorMessage ??
        'An unexpected error occurred. Please try again';
  }
}
