import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/monetization/domain/entities/promo_code_redemption.dart';

abstract class PromoCodeRepository {
  Future<Either<Failure, PromoRedemptionResult>> redeemPromoCode({
    required String code,
  });
}
