import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/monetization/domain/entities/promo_code_redemption.dart';
import 'package:kortex/src/features/monetization/domain/repositories/promo_code_repository.dart';

class RedeemPromoCodeParams extends Equatable {
  const RedeemPromoCodeParams({required this.code});
  final String code;

  @override
  List<Object?> get props => [code];
}

class RedeemPromoCodeUseCase
    with UseCase<PromoRedemptionResult, RedeemPromoCodeParams> {
  const RedeemPromoCodeUseCase(this._repository);

  final PromoCodeRepository _repository;

  @override
  Future<Either<Failure, PromoRedemptionResult>> call(
    RedeemPromoCodeParams params,
  ) {
    return _repository.redeemPromoCode(code: params.code);
  }
}
