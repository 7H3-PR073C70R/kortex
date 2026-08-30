import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/error_message_handler.dart';

extension RepositoryExtension<T> on Future<T> {
  /// Asynchronously makes a request to the server and handles exceptions.
  ///
  /// Returns a [Future] that resolves to an [Either] object, which represents
  /// either a successful response ([Right]) containing the data, or a
  /// failure ([Left]) with an appropriate error message.
  ///
  /// Optionally, you can provide [onSuccess] and [onFailure] callbacks to
  /// execute when the request succeeds or fails, respectively.
  Future<Either<Failure, T>> makeRequest({
    ValueChanged<T>? onSuccess,
    VoidCallback? onFailure,
  }) async {
    try {
      final data = await this;
      onSuccess?.call(data);
      return Right(data);
    } on DioException catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      debugPrintStack();
      return Left(
        ServerFailure(
          message: e.errorMessage,
        ),
      );
    } on ServerException catch (e, s) {
      onFailure?.call();
      debugPrint(e.toString());
      debugPrint(s.toString());
      debugPrintStack();
      return Left(
        ServerFailure(
          message: e.errorMessage,
        ),
      );
    } on Object catch (e, s) {
      onFailure?.call();
      debugPrint(e.toString());
      debugPrint(s.toString());
      debugPrintStack();
      return const Left(
        ServerFailure(
          message: 'Something went wrong. Please try again',
        ),
      );
    }
  }
}
