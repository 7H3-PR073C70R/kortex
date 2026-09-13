import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/monetization/data/datasources/promo_code_remote_data_source.dart';
import 'package:kortex/src/features/monetization/data/models/promo_code_model.dart';
import 'package:kortex/src/features/monetization/data/repositories/promo_code_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockPromoCodeRemoteDataSource extends Mock
    implements PromoCodeRemoteDataSource {}

class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  late MockPromoCodeRemoteDataSource mockRemoteDataSource;
  late MockUserStorageService mockUserStorageService;
  late PromoCodeRepositoryImpl repository;

  setUp(() {
    mockRemoteDataSource = MockPromoCodeRemoteDataSource();
    mockUserStorageService = MockUserStorageService();
    repository = PromoCodeRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      userStorageService: mockUserStorageService,
    );
  });

  group('PromoCodeRepositoryImpl', () {
    test(
      'redeemPromoCode saves Pro status on successful redemption and returns result',
      () async {
        const model = PromoRedemptionResultModel(
          success: true,
          code: 'kotexify007',
          durationDays: 365,
          message: 'Activated',
        );

        when(
          () => mockRemoteDataSource.redeemPromoCode(code: 'kotexify007'),
        ).thenAnswer((_) async => model);
        when(
          () => mockUserStorageService.saveProStatus(isPro: true),
        ).thenAnswer((_) async {});

        final result = await repository.redeemPromoCode(code: 'kotexify007');

        expect(result.isRight, isTrue);
        result.fold(
          (failure) => fail('Should be right'),
          (redemption) {
            expect(redemption.success, isTrue);
            expect(redemption.durationDays, equals(365));
          },
        );

        verify(
          () => mockUserStorageService.saveProStatus(isPro: true),
        ).called(1);
      },
    );

    test(
      'redeemPromoCode does not save Pro status when code is invalid/fails',
      () async {
        const model = PromoRedemptionResultModel(
          success: false,
          errorCode: 'INVALID_CODE',
          message: 'Invalid code',
        );

        when(
          () => mockRemoteDataSource.redeemPromoCode(code: 'fake_code'),
        ).thenAnswer((_) async => model);

        final result = await repository.redeemPromoCode(code: 'fake_code');

        expect(result.isRight, isTrue);
        result.fold(
          (failure) => fail('Should be right'),
          (redemption) {
            expect(redemption.success, isFalse);
            expect(redemption.errorCode, equals('INVALID_CODE'));
          },
        );

        verifyNever(() => mockUserStorageService.saveProStatus(isPro: true));
      },
    );

    test('redeemPromoCode returns ServerFailure on ServerException', () async {
      when(
        () => mockRemoteDataSource.redeemPromoCode(code: 'kotexify007'),
      ).thenThrow(const ServerException(message: 'Server unreachable'));

      final result = await repository.redeemPromoCode(code: 'kotexify007');

      expect(result.isLeft, isTrue);
      result.fold(
        (failure) => expect(failure.message, equals('Server unreachable')),
        (redemption) => fail('Should be left'),
      );
    });
  });
}
