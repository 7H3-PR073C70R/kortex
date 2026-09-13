import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/monetization/data/datasources/promo_code_remote_data_source_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late PromoCodeRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = PromoCodeRemoteDataSourceImpl(dio: mockDio);
  });

  group('PromoCodeRemoteDataSourceImpl', () {
    test('redeemPromoCode returns PromoRedemptionResultModel on successful RPC call', () async {
      when(
        () => mockDio.post<dynamic>(
          AppApiEndpoint.redeemPromoCodeRpc,
          data: {'code_input': 'kotexify007'},
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: AppApiEndpoint.redeemPromoCodeRpc),
          statusCode: 200,
          data: {
            'success': true,
            'code': 'kotexify007',
            'duration_days': 365,
            'message': 'Promo code redeemed successfully!',
          },
        ),
      );

      final result = await dataSource.redeemPromoCode(code: 'kotexify007');

      expect(result.success, isTrue);
      expect(result.code, equals('kotexify007'));
      expect(result.durationDays, equals(365));
    });

    test('redeemPromoCode throws ServerException on unexpected DioException', () async {
      when(
        () => mockDio.post<dynamic>(
          AppApiEndpoint.redeemPromoCodeRpc,
          data: {'code_input': 'invalid_code'},
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: AppApiEndpoint.redeemPromoCodeRpc),
          message: 'Connection timeout',
        ),
      );

      expect(
        () => dataSource.redeemPromoCode(code: 'invalid_code'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
