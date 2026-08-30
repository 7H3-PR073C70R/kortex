import 'package:dio/dio.dart';
import 'package:kortex/src/core/error/exceptions.dart';

extension ErrorHandler on Exception {
  String? get errorMessage {
    try {
      if (this is DioException) {
        final error = this as DioException;
        final backendMessage =
            (error.response?.data as Map?)?['message'] as String?;
        final message =
            backendMessage ?? error.message ?? 'something went wrong';
        return message.toLowerCase().contains('failed host lookup')
            ? 'Please check your internet connection and try again'
            : message;
      } else if (this is ServerException) {
        return (this as ServerException).message;
      } else {
        return null;
      }
    } on Exception catch (_) {
      return null;
    }
  }
}
