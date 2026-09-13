import 'package:kortex/src/features/monetization/data/models/promo_code_model.dart';

abstract class PromoCodeRemoteDataSource {
  Future<PromoRedemptionResultModel> redeemPromoCode({
    required String code,
  });
}
