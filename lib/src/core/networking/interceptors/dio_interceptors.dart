import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/services/user_storage_service.dart';
import 'package:logger/logger.dart';

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.logger});

  final Logger? logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger?.i(
      'REQUEST[${options.method}] => URL: ${options.uri}\n'
      'REQUEST DATA => ${options.data}\n'
      'Headers: ${options.headers}',
    );

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    logger?.i(
      'RESPONSE[${response.statusCode}] =>'
      ' PATH:${response.requestOptions.path}\n'
      'RESPONSE DATA: ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    logger?.e(
      'ERROR[${err.requestOptions.uri}]\n'
      'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}\n'
      'ERROR[${err.response?.data}]',
    );
    super.onError(err, handler);
  }
}

class TokenInterceptor extends Interceptor {
  TokenInterceptor({required this.storageService});

  final UserStorageService storageService;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final userToken = storageService.getToken();
    final anonKey = AppEnv.supabaseAnonKey;

    if (anonKey.isNotEmpty) {
      options.headers['apikey'] = anonKey;
    }

    if (userToken != null && userToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $userToken';
    } else if (anonKey.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $anonKey';
    }

    super.onRequest(options, handler);
  }
}

class DataParserInterceptor extends Interceptor {
  DataParserInterceptor();

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) {
        response.data = data['data'];
      }
    }
    super.onResponse(response, handler);
  }
}
