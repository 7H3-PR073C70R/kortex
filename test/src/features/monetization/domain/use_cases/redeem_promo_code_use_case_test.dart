import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/monetization/domain/entities/promo_code_redemption.dart';
import 'package:kortex/src/features/monetization/domain/repositories/promo_code_repository.dart';
import 'package:kortex/src/features/monetization/domain/use_cases/redeem_promo_code_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockPromoCodeRepository extends Mock implements PromoCodeRepository {}

void main() {
  late MockPromoCodeRepository mockRepository;
  late RedeemPromoCodeUseCase useCase;

  setUp(() {
    mockRepository = MockPromoCodeRepository();
    useCase = RedeemPromoCodeUseCase(mockRepository);
  });

  group('RedeemPromoCodeUseCase', () {
    test(
      'delegates redemption to PromoCodeRepository with correct code',
      () async {
        const expectedResult = PromoRedemptionResult(
          success: true,
          code: 'kotexify007',
          durationDays: 365,
          message: '1 Year Pro Activated',
        );

        when(
          () => mockRepository.redeemPromoCode(code: 'kotexify007'),
        ).thenAnswer((_) async => const Right(expectedResult));

        final result = await useCase(
          const RedeemPromoCodeParams(code: 'kotexify007'),
        );

        expect(result.isRight, isTrue);
        result.fold(
          (failure) => fail('Should be right'),
          (redemption) {
            expect(redemption.success, isTrue);
            expect(redemption.code, equals('kotexify007'));
            expect(redemption.durationDays, equals(365));
          },
        );

        verify(
          () => mockRepository.redeemPromoCode(code: 'kotexify007'),
        ).called(1);
      },
    );
  });
}
