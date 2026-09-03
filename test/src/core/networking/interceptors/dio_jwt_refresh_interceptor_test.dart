import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/networking/interceptors/dio_interceptors.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';

class InMemoryLocalStorage implements LocalStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> initDB() async {}

  @override
  Future<void> deletePreference({required String key}) async =>
      _store.remove(key);

  @override
  String? getPreference({required String key}) => _store[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async => _store[key] = data;
}

class _MockErrorHandler extends ErrorInterceptorHandler {
  DioException? errorPassed;
  Response<dynamic>? resolvedResponse;

  @override
  void next(DioException err) {
    errorPassed = err;
  }

  @override
  void resolve(Response<dynamic> response) {
    resolvedResponse = response;
  }

  @override
  void reject(DioException err, [bool? test]) {
    errorPassed = err;
  }
}

void main() {
  group('TokenInterceptor & JWT Expiration / Refresh Token Suite', () {
    late InMemoryLocalStorage localStorage;
    late UserStorageService storageService;
    late SessionExpiredService sessionExpiredService;

    setUp(() {
      localStorage = InMemoryLocalStorage();
      storageService = UserStorageServiceImpl(localStorage);
      sessionExpiredService = SessionExpiredService();
    });

    tearDown(() {
      sessionExpiredService.dispose();
    });

    test('adds Authorization header on request when token exists', () async {
      await storageService.saveToken('test_access_token');

      final interceptor = TokenInterceptor(
        storageService: storageService,
        sessionExpiredService: sessionExpiredService,
      );

      final options = RequestOptions(path: '/rest/v1/profiles');
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer test_access_token');
    });

    test(
      'attempts token refresh when PGRST303 / JWT expired is returned and retries request',
      () async {
        await storageService.saveAuthTokens(
          accessToken: 'expired_access_token',
          refreshToken: 'valid_refresh_token',
        );

        final refreshDio = Dio();
        refreshDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.contains(AppApiEndpoint.refreshToken)) {
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'access_token': 'new_refreshed_access_token',
                      'refresh_token': 'new_refreshed_refresh_token',
                    },
                  ),
                );
              }
              if (options.headers['Authorization'] ==
                  'Bearer new_refreshed_access_token') {
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {'success': true},
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        final interceptor = TokenInterceptor(
          storageService: storageService,
          sessionExpiredService: sessionExpiredService,
          refreshDio: refreshDio,
        );

        final requestOptions = RequestOptions(path: '/rest/v1/profiles');
        final expiredException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
            data: {
              'code': 'PGRST303',
              'message': 'JWT expired',
            },
          ),
        );

        final handler = _MockErrorHandler();

        await interceptor.onError(expiredException, handler);

        expect(handler.resolvedResponse, isNotNull);
        expect(handler.resolvedResponse?.data, {'success': true});
        expect(storageService.getToken(), 'new_refreshed_access_token');
        expect(storageService.getRefreshToken(), 'new_refreshed_refresh_token');
      },
    );

    test('clears storage and triggers session expiration notification '
        'when refresh fails', () async {
      await storageService.saveAuthTokens(
        accessToken: 'expired_token',
        refreshToken: 'invalid_refresh_token',
      );

      final refreshDio = Dio();
      refreshDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {'error': 'invalid_grant'},
                ),
              ),
            );
          },
        ),
      );

      final interceptor = TokenInterceptor(
        storageService: storageService,
        sessionExpiredService: sessionExpiredService,
        refreshDio: refreshDio,
      );

      final expiredEvents = <String>[];
      final sub = sessionExpiredService.onSessionExpired.listen(
        expiredEvents.add,
      );

      final requestOptions = RequestOptions(path: '/rest/v1/profiles');
      final expiredException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {
            'code': 'PGRST303',
            'message': 'JWT expired',
          },
        ),
      );

      final handler = _MockErrorHandler();

      await interceptor.onError(expiredException, handler);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(storageService.getToken(), isNull);
      expect(storageService.getRefreshToken(), isNull);
      expect(expiredEvents.isNotEmpty, isTrue);
      expect(handler.errorPassed, isNotNull);

      await sub.cancel();
    });
  });
}
